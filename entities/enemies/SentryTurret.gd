# res://entities/enemies/SentryTurret.gd
# Авто-турель. Спит, пока нет тревоги (или не взято золото, если climax=true).
# В активном режиме: крутится на 90° каждый ход; увидев игрока на линии огня — «захват» (красный прицел),
# и на СЛЕДУЮЩЕМ ходу стреляет, если игрок всё ещё на линии. Поэтому у игрока всегда есть ход, чтобы уйти.
class_name SentryTurret
extends GridEntity

const RANGE_TILES: int = 7

var group_id: String = ""
var climax: bool = false          # включается навсегда после кражи золота
var emp_turns: int = 0
var locked: bool = false
var ray_cells: Array[Vector2i] = []


func is_armed(sim: TurnManager) -> bool:
	if emp_turns > 0 or sim.is_group_off(group_id):
		return false
	return sim.alarm.is_alarm() or (climax and sim.loot_taken)


func recompute_ray(sim: TurnManager) -> void:
	if not is_armed(sim):
		ray_cells = []
		return
	ray_cells = VisionCone2D.straight_ray(grid_pos, facing, RANGE_TILES, sim.grid, false)


# Фаза 4 (окружение): выстрел по захваченной цели или поворот.
func step_turn(sim: TurnManager) -> void:
	if not is_armed(sim):
		locked = false
		return
	if locked:
		recompute_ray(sim)
		if sim.player_is_targetable() and ray_cells.has(sim.player.grid_pos):
			sim.turret_fire(self)
		locked = false
		return
	facing = GridManager.rot_cw(facing)


# Фаза 5 (зрение): захват цели.
func update_lock(sim: TurnManager) -> void:
	recompute_ray(sim)
	locked = false
	if is_armed(sim) and sim.player_is_targetable() and ray_cells.has(sim.player.grid_pos):
		locked = true


func get_state() -> Dictionary:
	return {"f": facing, "l": locked, "m": emp_turns}


func set_state(d: Dictionary) -> void:
	facing = d["f"]
	locked = d["l"]
	emp_turns = d["m"]
