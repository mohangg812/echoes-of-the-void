# res://entities/enemies/BaseEnemy.gd
# Охранник (обычный и элитный). Детерминированный конечный автомат из 6 состояний:
# PATROL, SUSPICIOUS_FREEZE, INVESTIGATE, CHASE, RETURN, STUNNED. Никакого RNG.
class_name BaseEnemy
extends GridEntity

enum AIState { PATROL, SUSPICIOUS_FREEZE, INVESTIGATE, CHASE, RETURN, STUNNED }

var is_elite: bool = false
var kind: String = "standard"       # standard | elite | hound | drone
var patrol_waypoints: Array[Vector2i] = []
var ping_pong: bool = true
var keycard_color: String = ""      # ключ-карта, которую можно украсть ("" — нет)
var dormant: bool = false           # резервный гвардеец: просыпается после кражи золота
var scan: bool = false              # часовой: поворачивается на месте
var wait_at_wp: int = 0

var state: int = AIState.PATROL
var wp_index: int = 0
var wp_direction: int = 1
var wait_left: int = 0
var investigate_target: Vector2i = Vector2i(-1, -1)
var look_around_turns: int = 0
var stun_turns: int = 0

var red_cells: Array[Vector2i] = []
var yellow_cells: Array[Vector2i] = []


func is_active() -> bool:
	return not dormant


func is_stunned() -> bool:
	return state == AIState.STUNNED


func view_range() -> int:
	match kind:
		"elite": return 6
		"hound": return 3
		"drone": return 5
	return 4


func half_angle() -> float:
	match kind:
		"elite": return 55.0
		"hound": return 75.0
		"drone": return 38.0
	return 45.0


func sharp_hearing() -> bool:
	return is_elite or kind == "hound"


func can_be_shocked() -> bool:
	return kind == "standard" or kind == "hound"


func steps_per_turn() -> int:
	if kind == "hound":
		return 2
	return 2 if (is_elite and state == AIState.CHASE) else 1


func recompute_vision(sim: TurnManager, ignore_cell: Vector2i) -> void:
	if dormant or state == AIState.STUNNED:
		red_cells = []
		yellow_cells = []
		return
	var res: Dictionary = VisionCone2D.compute(grid_pos, facing, view_range(), half_angle(), sim.grid, ignore_cell)
	red_cells = res["red"]
	yellow_cells = res["yellow"]


func stun(turns: int) -> void:
	state = AIState.STUNNED
	stun_turns = turns
	red_cells = []
	yellow_cells = []


func begin_investigate(sim: TurnManager, target: Vector2i) -> void:
	investigate_target = sim.grid.nearest_ai_cell(target, grid_pos)
	face_towards(target)


# Один такт ИИ (фаза 3 TurnManager).
func decide_next_step(sim: TurnManager) -> void:
	if dormant:
		return
	if state == AIState.STUNNED:
		stun_turns -= 1
		if stun_turns <= 0:
			if sim.alarm.is_alarm():
				state = AIState.CHASE
			else:
				state = AIState.INVESTIGATE
				investigate_target = grid_pos
				look_around_turns = 2
		return

	var steps: int = steps_per_turn()
	sim.last_guard_attacked = false
	for _i in range(steps):
		if sim.last_guard_attacked:
			return
		match state:
			AIState.PATROL:
				_step_patrol(sim)
			AIState.SUSPICIOUS_FREEZE:
				# Замирает на 1 такт, глядя на источник подозрения.
				face_towards(investigate_target)
				state = AIState.INVESTIGATE
				look_around_turns = 2
				return
			AIState.INVESTIGATE:
				if grid_pos != investigate_target:
					if not _move_along_astar(sim, investigate_target):
						look_around_turns = 0
						state = AIState.RETURN
				elif look_around_turns > 0:
					look_around_turns -= 1
					facing = GridManager.rot_cw(facing)
				else:
					state = AIState.RETURN
			AIState.CHASE:
				var target: Vector2i = sim.alarm.last_known_player_pos
				if _can_pull_from_closet(sim):
					sim.guard_attack(self)
					return
				var goal: Vector2i = sim.grid.nearest_ai_cell(target, grid_pos)
				if grid_pos != goal:
					var moved: bool = _move_along_astar(sim, goal)
					if not moved and not sim.last_guard_attacked:
						facing = GridManager.rot_cw(facing)
				else:
					facing = GridManager.rot_cw(facing)
			AIState.RETURN:
				var home: Vector2i = patrol_waypoints[wp_index] if patrol_waypoints.size() > 0 else start_grid_pos
				if grid_pos != home:
					_move_along_astar(sim, home)
				else:
					state = AIState.PATROL


func _can_pull_from_closet(sim: TurnManager) -> bool:
	var p: PlayerController = sim.player
	if not p.closet_exposed:
		return false
	return absi(p.grid_pos.x - grid_pos.x) + absi(p.grid_pos.y - grid_pos.y) == 1


func _step_patrol(sim: TurnManager) -> void:
	var n: int = patrol_waypoints.size()
	if n == 0 or (n == 1 and grid_pos == patrol_waypoints[0]):
		if scan:
			facing = GridManager.rot_cw(facing)
		return
	if wait_left > 0:
		wait_left -= 1
		return
	var target: Vector2i = patrol_waypoints[wp_index]
	if grid_pos == target:
		_advance_waypoint()
		target = patrol_waypoints[wp_index]
	_move_along_astar(sim, target)
	if grid_pos == target:
		wait_left = wait_at_wp


func _advance_waypoint() -> void:
	var n: int = patrol_waypoints.size()
	if n <= 1:
		return
	if ping_pong:
		wp_index += wp_direction
		if wp_index >= n or wp_index < 0:
			wp_direction = -wp_direction
			wp_index += 2 * wp_direction
	else:
		wp_index = (wp_index + 1) % n


# Возвращает true, если охранник сдвинулся с места.
func _move_along_astar(sim: TurnManager, target: Vector2i) -> bool:
	var path: Array[Vector2i] = sim.grid.find_path(grid_pos, target)
	if path.size() <= 1:
		return false
	var next_cell: Vector2i = path[1]
	if next_cell == sim.player.grid_pos:
		sim.guard_attack(self)
		return false
	if sim.grid.guard_cells.has(next_cell) or sim.grid.solid_entities.has(next_cell):
		return false
	var move_dir: Vector2i = next_cell - grid_pos
	if move_dir != Vector2i.ZERO:
		facing = move_dir
	sim.guard_moved(self, next_cell)
	return true


func get_state() -> Dictionary:
	return {
		"p": grid_pos, "f": facing, "s": state, "wi": wp_index, "wd": wp_direction, "wl": wait_left,
		"it": investigate_target, "la": look_around_turns, "st": stun_turns,
		"kc": keycard_color, "dm": dormant,
	}


func set_state(d: Dictionary) -> void:
	grid_pos = d["p"]
	facing = d["f"]
	state = d["s"]
	wp_index = d["wi"]
	wp_direction = d["wd"]
	wait_left = d["wl"]
	investigate_target = d["it"]
	look_around_turns = d["la"]
	stun_turns = d["st"]
	keycard_color = d["kc"]
	dormant = d["dm"]
