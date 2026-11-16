# res://core/TurnManager.gd
# Детерминированный менеджер ходов и вся «симуляция мира». Один ход игрока = один такт мира.
# Конвейер:  PLAYER_ACTION -> GADGETS_AND_SMOKE -> AI_DECISION_AND_MOVE -> ENVIRONMENT_AND_LASERS
#            -> VISION_AND_DETECTION -> TURN_RESOLUTION -> AWAITING_INPUT.
# Класс не знает про картинку: вьюха (MainGame) читает состояние и список событий.
class_name TurnManager
extends RefCounted

enum TurnPhase {
	AWAITING_INPUT, PLAYER_ACTION, GADGETS_AND_SMOKE, AI_DECISION_AND_MOVE,
	ENVIRONMENT_AND_LASERS, VISION_AND_DETECTION, TURN_RESOLUTION, GAME_OVER_LOCKED,
}

const SMOKE_TURNS: int = 3
const EMP_TURNS: int = 4

var current_phase: int = TurnPhase.AWAITING_INPUT
var turn_number: int = 0
var grid: GridManager = GridManager.new()
var alarm: AlarmManager = AlarmManager.new()
var player: PlayerController = PlayerController.new()
var guards: Array[BaseEnemy] = []
var cameras: Array[SecurityCamera] = []
var turrets: Array[SentryTurret] = []
var lasers: Array[LaserEmitter] = []
var switches: Array[PowerSwitch] = []
var doors: Array[ElectronicDoor] = []
var loot: Array[LootItem] = []
var history: TacticalHistory = TacticalHistory.new()

var level_data: Dictionary = {}
var loot_taken: bool = false
var chips_total: int = 0
var undo_count: int = 0
var result: String = ""               # "" | "won" | "lost"
var fail_reason: String = ""
var events: Array = []
var laser_cells: Dictionary = {}      # Vector2i -> LaserEmitter (лучи, действующие в текущем такте)
var last_guard_attacked: bool = false
var dry_run: bool = false
var noise_queue: Array = []
var turn_player_seen: bool = false
var hp_lost: int = 0
var combo: int = 0
var last_style_turn: int = -99
var stats: Dictionary = {"pick": 0, "gadgets": 0, "takedowns": 0, "dash": 0, "maxmult": 1}


static func card_name(c: String) -> String:
	match c:
		"RED": return "КРАСНАЯ"
		"BLUE": return "СИНЯЯ"
		"YELLOW": return "ЖЁЛТАЯ"
	return c


# ───────────────────────────── запросы ─────────────────────────────

func is_group_off(group_id: String) -> bool:
	if group_id == "":
		return false
	for sw in switches:
		if sw.on and sw.target_group_id == group_id:
			return true
	return false


func guard_at(cell: Vector2i) -> BaseEnemy:
	for g in guards:
		if g.is_active() and g.grid_pos == cell:
			return g
	return null


func switch_near(cell: Vector2i) -> PowerSwitch:
	for sw in switches:
		if absi(sw.grid_pos.x - cell.x) + absi(sw.grid_pos.y - cell.y) <= 1:
			return sw
	return null


func player_is_targetable() -> bool:
	return player.cloak_turns <= 0


func is_cell_seen(cell: Vector2i) -> bool:
	for g in guards:
		if g.is_active() and not g.is_stunned():
			if g.red_cells.has(cell) or g.yellow_cells.has(cell):
				return true
	for c in cameras:
		if c.is_active(self) and (c.red_cells.has(cell) or c.yellow_cells.has(cell)):
			return true
	return false


func combo_mult() -> int:
	return mini(5, 1 + combo / 2)


# Очки за стиль: цепочка чистых действий даёт множитель до x5; тревога обрывает цепочку.
func award_style(text: String, pts: int) -> void:
	if dry_run:
		return
	if turn_number - last_style_turn > 6:
		combo = 0
	combo += 1
	last_style_turn = turn_number
	var gain: int = pts * combo_mult()
	stats["maxmult"] = maxi(int(stats["maxmult"]), combo_mult())
	player.score += gain
	add_event({"t": "style", "text": text, "pts": gain, "mult": combo_mult(), "combo": combo})


func add_event(e: Dictionary) -> void:
	if not dry_run:
		events.append(e)


func add_noise(cell: Vector2i, radius: int, is_decoy: bool = false) -> void:
	noise_queue.append({"cell": cell, "r": radius, "decoy": is_decoy})


func get_rating() -> String:
	var par: int = int(level_data.get("par_turns", 40))
	var alarms: int = alarm.times_triggered
	var all_chips: bool = player.chips >= chips_total
	if alarms == 0 and turn_number <= par and all_chips:
		return "S"
	if alarms <= 1 and turn_number <= int(par * 1.35) and (all_chips or alarms == 0):
		return "A"
	if alarms <= 3:
		return "B"
	return "C"


# ───────────────────────────── эффекты, вызываемые сущностями ─────────────────────────────

func guard_moved(g: BaseEnemy, cell: Vector2i) -> void:
	grid.guard_cells.erase(g.grid_pos)
	g.grid_pos = cell
	grid.guard_cells[cell] = true


func guard_attack(g: BaseEnemy) -> void:
	last_guard_attacked = true
	if dry_run:
		return
	player.hp -= 1
	hp_lost += 1
	add_event({"t": "hit", "pos": player.grid_pos, "by": g.id, "text": "Захвачен охраной!"})
	trigger_alarm(player.grid_pos, "Контакт с охраной")


func turret_fire(t: SentryTurret) -> void:
	if dry_run:
		return
	player.hp -= 1
	hp_lost += 1
	add_event({"t": "shot", "from": t.grid_pos, "to": player.grid_pos, "id": t.id})
	trigger_alarm(player.grid_pos, "Выстрел турели")


func trigger_alarm(pos: Vector2i, reason: String) -> void:
	if dry_run:
		return
	var fresh: bool = alarm.trigger(pos)
	turn_player_seen = true
	if fresh:
		combo = 0
	if fresh:
		add_event({"t": "alarm_on", "reason": reason, "pos": pos})
	for g in guards:
		if g.is_active() and not g.is_stunned() and g.state != BaseEnemy.AIState.CHASE:
			g.state = BaseEnemy.AIState.CHASE
			g.look_around_turns = 0


func toggle_switch(sw: PowerSwitch) -> void:
	sw.on = not sw.on
	for d in doors:
		if d.group_id != "" and d.group_id == sw.target_group_id:
			d.group_open = is_group_off(d.group_id)
	add_event({"t": "switch", "pos": sw.grid_pos, "on": sw.on, "text": sw.description})


func deploy_smoke(center: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = center + Vector2i(dx, dy)
			if not grid.is_in_bounds(c):
				continue
			var t: int = grid.get_tile(c)
			if t == GridManager.TileType.WALL or t == GridManager.TileType.VOID or t == GridManager.TileType.SERVER:
				continue
			grid.smoke_cells[c] = SMOKE_TURNS
	add_event({"t": "smoke", "pos": center})


func emp_pulse(center: Vector2i, radius: int) -> void:
	add_event({"t": "emp", "pos": center, "r": radius})
	for c in cameras:
		if _cheb(c.grid_pos, center) <= radius:
			c.emp_turns = EMP_TURNS
	for t in turrets:
		if _cheb(t.grid_pos, center) <= radius:
			t.emp_turns = EMP_TURNS
			t.locked = false
	for l in lasers:
		if _cheb(l.grid_pos, center) <= radius:
			l.emp_turns = EMP_TURNS
	for g in guards:
		if g.is_active() and not g.is_stunned() and _cheb(g.grid_pos, center) <= radius:
			g.stun(EMP_TURNS + 1)
			add_event({"t": "stun", "pos": g.grid_pos, "id": g.id})


func on_gold_taken() -> void:
	loot_taken = true
	var has_climax: bool = false
	for l0 in lasers:
		if l0.activate_on_loot:
			has_climax = true
	for g0 in guards:
		if g0.dormant:
			has_climax = true
	for t0 in turrets:
		if t0.climax:
			has_climax = true
	if has_climax:
		add_event({"t": "climax"})
	for l in lasers:
		if l.activate_on_loot:
			l.enabled = true
	for g in guards:
		if g.dormant:
			g.dormant = false
			g.state = BaseEnemy.AIState.CHASE if alarm.is_alarm() else BaseEnemy.AIState.INVESTIGATE
			g.investigate_target = grid.nearest_ai_cell(player.grid_pos, g.grid_pos)
			g.look_around_turns = 2
			grid.guard_cells[g.grid_pos] = true
			add_event({"t": "spawn_guard", "id": g.id, "pos": g.grid_pos})


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ───────────────────────────── ход игрока ─────────────────────────────

# action: {"type": "move"|"dash"|"wait"|"takedown"|"interact"|"gadget", "dir": Vector2i, "slot": int, "target": Vector2i}
# Возвращает {"ok": bool, "msg": String, "events": Array}. При ok=false ход НЕ тратится.
func execute_player_turn(action: Dictionary) -> Dictionary:
	if current_phase == TurnPhase.GAME_OVER_LOCKED or result != "":
		return {"ok": false, "msg": "", "events": []}
	var snap: Dictionary = snapshot()
	events = []
	noise_queue = []
	last_guard_attacked = false
	turn_player_seen = false
	current_phase = TurnPhase.PLAYER_ACTION
	turn_number += 1
	var res: Dictionary = player.perform_turn_action(self, action)
	if not bool(res["ok"]):
		turn_number -= 1
		noise_queue = []
		events = []
		current_phase = TurnPhase.AWAITING_INPUT
		return {"ok": false, "msg": String(res["msg"]), "events": []}
	history.push(snap)
	_resolve_noise()
	if player.hp > 0:
		current_phase = TurnPhase.GADGETS_AND_SMOKE
		current_phase = TurnPhase.AI_DECISION_AND_MOVE
		_phase_ai()
		current_phase = TurnPhase.ENVIRONMENT_AND_LASERS
		_phase_environment()
		current_phase = TurnPhase.VISION_AND_DETECTION
		_phase_vision(true)
	current_phase = TurnPhase.TURN_RESOLUTION
	_phase_resolution()
	return {"ok": true, "msg": String(res["msg"]), "events": events.duplicate()}


func _resolve_noise() -> void:
	for n in noise_queue:
		var cell: Vector2i = n["cell"]
		var radius: int = n["r"]
		if radius < 1:
			continue
		var dist_map: Dictionary = AcousticSystem.flood(grid, cell, radius + 1)
		for g in guards:
			if not g.is_active() or g.is_stunned() or g.state == BaseEnemy.AIState.CHASE:
				continue
			if not AcousticSystem.guard_hears(grid, g.grid_pos, g.sharp_hearing(), cell, radius, dist_map):
				continue
			if g.state == BaseEnemy.AIState.SUSPICIOUS_FREEZE or g.state == BaseEnemy.AIState.INVESTIGATE:
				g.begin_investigate(self, cell)
				g.look_around_turns = 2
			else:
				g.state = BaseEnemy.AIState.SUSPICIOUS_FREEZE
				g.begin_investigate(self, cell)
			add_event({"t": "heard", "id": g.id, "pos": g.grid_pos})
	noise_queue = []


func _phase_ai() -> void:
	var order: Array[BaseEnemy] = []
	for g in guards:
		if g.is_elite:
			order.append(g)
	for g in guards:
		if not g.is_elite:
			order.append(g)
	for g in order:
		if g.is_active():
			var before: Vector2i = g.grid_pos
			g.decide_next_step(self)
			if g.grid_pos != before:
				add_event({"t": "guard_move", "id": g.id, "from": before, "to": g.grid_pos})


func _phase_environment() -> void:
	for c in cameras:
		c.step_turn(self)
	_rebuild_laser_cells(turn_number)
	for t in turrets:
		t.step_turn(self)
	_check_laser_intersection()


func _rebuild_laser_cells(turn: int) -> void:
	laser_cells.clear()
	for l in lasers:
		if l.is_firing(self, turn):
			for c in l.beam_cells(grid):
				laser_cells[c] = l


func _check_laser_intersection() -> void:
	if dry_run:
		return
	if player.hp > 0 and laser_cells.has(player.grid_pos):
		add_event({"t": "laser_hit", "pos": player.grid_pos})
		trigger_alarm(player.grid_pos, "Пересечён лазер")


func _ignore_cell() -> Vector2i:
	return player.grid_pos if player.closet_exposed else VisionCone2D.NO_CELL


func refresh_vision() -> void:
	var ic: Vector2i = _ignore_cell()
	for g in guards:
		g.recompute_vision(self, ic)
	for c in cameras:
		c.recompute(self, ic)
	for t in turrets:
		t.recompute_ray(self)


func _phase_vision(detect: bool) -> void:
	refresh_vision()
	for t in turrets:
		t.update_lock(self)
	if not detect or dry_run:
		return
	if player.cloak_turns > 0:
		return
	var p: Vector2i = player.grid_pos
	var spotted_red: bool = false
	var yellow_guards: Array[BaseEnemy] = []
	for g in guards:
		if not g.is_active() or g.is_stunned():
			continue
		if g.red_cells.has(p):
			spotted_red = true
			add_event({"t": "spotted", "id": g.id, "pos": g.grid_pos})
		elif g.yellow_cells.has(p):
			yellow_guards.append(g)
	for c in cameras:
		if not c.is_active(self):
			continue
		if c.red_cells.has(p):
			spotted_red = true
			add_event({"t": "spotted_cam", "id": c.id, "pos": c.grid_pos})
		elif c.yellow_cells.has(p):
			turn_player_seen = true
	if spotted_red:
		turn_player_seen = true
		trigger_alarm(p, "Обнаружен")
		return
	if not yellow_guards.is_empty():
		turn_player_seen = true
	for g in yellow_guards:
		match g.state:
			BaseEnemy.AIState.PATROL, BaseEnemy.AIState.RETURN:
				g.state = BaseEnemy.AIState.SUSPICIOUS_FREEZE
				g.begin_investigate(self, p)
				add_event({"t": "suspicious", "id": g.id, "pos": g.grid_pos})
			BaseEnemy.AIState.INVESTIGATE, BaseEnemy.AIState.SUSPICIOUS_FREEZE:
				g.begin_investigate(self, p)
				g.look_around_turns = 2


func _phase_resolution() -> void:
	var seen_for_cooldown: bool = turn_player_seen
	if alarm.is_alarm():
		if alarm.step_turn_cooldown(seen_for_cooldown, player.grid_pos):
			add_event({"t": "alarm_off"})
			for g in guards:
				if g.is_active() and not g.is_stunned() and g.state != BaseEnemy.AIState.PATROL:
					g.state = BaseEnemy.AIState.RETURN
	else:
		var suspicious: bool = false
		for g in guards:
			if g.is_active() and (g.state == BaseEnemy.AIState.SUSPICIOUS_FREEZE or g.state == BaseEnemy.AIState.INVESTIGATE):
				suspicious = true
		alarm.state = AlarmManager.State.SUSPICION if suspicious else AlarmManager.State.STEALTH

	_check_near_miss()
	# Таймеры
	for c in smoke_keys():
		grid.smoke_cells[c] = int(grid.smoke_cells[c]) - 1
		if int(grid.smoke_cells[c]) <= 0:
			grid.smoke_cells.erase(c)
	for c in cameras:
		c.emp_turns = maxi(0, c.emp_turns - 1)
	for t in turrets:
		t.emp_turns = maxi(0, t.emp_turns - 1)
	for l in lasers:
		l.emp_turns = maxi(0, l.emp_turns - 1)
	player.cloak_turns = maxi(0, player.cloak_turns - 1)
	player.dash_cd = maxi(0, player.dash_cd - 1)

	if player.hp <= 0:
		current_phase = TurnPhase.GAME_OVER_LOCKED
		result = "lost"
		fail_reason = "Агент ликвидирован"
		add_event({"t": "lost", "text": fail_reason})
	elif _check_victory():
		current_phase = TurnPhase.GAME_OVER_LOCKED
		result = "won"
		add_event({"t": "won"})
	else:
		current_phase = TurnPhase.AWAITING_INPUT


# «Впритык»: игрок закончил ход рядом с зоной зрения, но остался невидимым.
func _check_near_miss() -> void:
	if dry_run or alarm.is_alarm() or turn_player_seen or player.hp <= 0:
		return
	var p: Vector2i = player.grid_pos
	for g in guards:
		if not g.is_active() or g.is_stunned():
			continue
		for d in GridManager.DIRS:
			var c: Vector2i = p + d
			if g.red_cells.has(c) or g.yellow_cells.has(c):
				award_style("ВПРИТЫК", 25)
				return


func smoke_keys() -> Array:
	return grid.smoke_cells.keys()


func _check_victory() -> bool:
	return player.has_gold and grid.get_tile(player.grid_pos) == GridManager.TileType.EXTRACTION \
		and not alarm.is_alarm()


# ───────────────────────────── снимки, откат, предпросмотр ─────────────────────────────

func snapshot() -> Dictionary:
	var s: Dictionary = {
		"turn": turn_number, "player": player.get_state(), "alarm": alarm.get_state(),
		"smoke": grid.smoke_cells.duplicate(), "lt": loot_taken, "hp_lost": hp_lost,
		"combo": combo, "lst": last_style_turn, "stats": stats.duplicate(),
		"guards": [], "cams": [], "turrets": [], "lasers": [], "switches": [], "doors": [], "loot": [],
	}
	for g in guards: s["guards"].append(g.get_state())
	for c in cameras: s["cams"].append(c.get_state())
	for t in turrets: s["turrets"].append(t.get_state())
	for l in lasers: s["lasers"].append(l.get_state())
	for sw in switches: s["switches"].append(sw.get_state())
	for d in doors: s["doors"].append(d.get_state())
	for it in loot: s["loot"].append(it.get_state())
	return s


func restore(s: Dictionary) -> void:
	turn_number = s["turn"]
	player.set_state(s["player"])
	alarm.set_state(s["alarm"])
	grid.smoke_cells = (s["smoke"] as Dictionary).duplicate()
	loot_taken = s["lt"]
	hp_lost = s["hp_lost"]
	combo = s["combo"]
	last_style_turn = s["lst"]
	stats = (s["stats"] as Dictionary).duplicate()
	for i in range(guards.size()): guards[i].set_state(s["guards"][i])
	for i in range(cameras.size()): cameras[i].set_state(s["cams"][i])
	for i in range(turrets.size()): turrets[i].set_state(s["turrets"][i])
	for i in range(lasers.size()): lasers[i].set_state(s["lasers"][i])
	for i in range(switches.size()): switches[i].set_state(s["switches"][i])
	for i in range(doors.size()): doors[i].set_state(s["doors"][i])
	for i in range(loot.size()): loot[i].set_state(s["loot"][i])
	grid.guard_cells.clear()
	for g in guards:
		if g.is_active():
			grid.guard_cells[g.grid_pos] = true
	current_phase = TurnPhase.AWAITING_INPUT
	result = ""
	fail_reason = ""
	noise_queue = []
	turn_player_seen = false
	_rebuild_laser_cells(turn_number)
	refresh_vision()
	for t in turrets:
		t.update_lock(self)


func undo() -> bool:
	if history.size() == 0:
		return false
	var s: Dictionary = history.pop()
	restore(s)
	undo_count += 1
	return true


# Что будет в следующем такте, если игрок ничего не изменит (ждёт на месте):
# позиции и конусы охраны, повороты камер, лучи лазеров, лучи турелей.
func compute_preview() -> Dictionary:
	var snap: Dictionary = snapshot()
	var saved_events: Array = events
	dry_run = true
	turn_number += 1
	_phase_ai()
	for c in cameras:
		c.step_turn(self)
	_rebuild_laser_cells(turn_number)
	for t in turrets:
		t.step_turn(self)
	refresh_vision()
	for t in turrets:
		t.update_lock(self)
	var out: Dictionary = {"guards": {}, "cams": {}, "turrets": {}, "lasers": laser_cells.duplicate()}
	for g in guards:
		if g.is_active():
			out["guards"][g.id] = {"pos": g.grid_pos, "facing": g.facing, "red": g.red_cells.duplicate(),
				"yellow": g.yellow_cells.duplicate(), "state": g.state}
	for c in cameras:
		out["cams"][c.id] = {"facing": c.facing, "red": c.red_cells.duplicate(), "yellow": c.yellow_cells.duplicate()}
	for t in turrets:
		out["turrets"][t.id] = {"facing": t.facing, "ray": t.ray_cells.duplicate(), "locked": t.locked}
	dry_run = false
	events = saved_events
	var saved_phase: int = current_phase
	var saved_result: String = result
	var saved_reason: String = fail_reason
	var saved_seen: bool = turn_player_seen
	restore(snap)
	current_phase = saved_phase
	result = saved_result
	fail_reason = saved_reason
	turn_player_seen = saved_seen
	return out
