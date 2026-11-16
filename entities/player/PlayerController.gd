# res://entities/player/PlayerController.gd
# Теневой вор: шаг, ожидание, рывок, вентиляция, шкафы, кража ключ-карт, оглушение со спины,
# взаимодействие и 4 гаджета. Возвращает {"ok": bool, "msg": String}; если ok=false, ход не тратится.
class_name PlayerController
extends GridEntity

const MAX_HP: int = 2
const DASH_COOLDOWN: int = 5       # 4 полных хода ожидания после рывка
const NO_CELL: Vector2i = Vector2i(-1, -1)

var hp: int = MAX_HP
var keycards: Array[String] = []
var gadgets: Dictionary = {"smoke": 0, "decoy": 0, "emp": 0, "cloak": 0, "shock": 1}
var dash_cd: int = 0
var cloak_turns: int = 0
var vent_charge: Vector2i = NO_CELL
var closet_exposed: bool = false
var has_gold: bool = false
var chips: int = 0
var score: int = 0


func get_state() -> Dictionary:
	return {
		"p": grid_pos, "f": facing, "hp": hp, "kc": keycards.duplicate(), "g": gadgets.duplicate(),
		"dc": dash_cd, "ct": cloak_turns, "vc": vent_charge, "ce": closet_exposed,
		"gold": has_gold, "chips": chips, "score": score,
	}


func set_state(d: Dictionary) -> void:
	grid_pos = d["p"]
	facing = d["f"]
	hp = d["hp"]
	keycards.clear()
	for k in d["kc"]:
		keycards.append(String(k))
	gadgets = d["g"].duplicate()
	dash_cd = d["dc"]
	cloak_turns = d["ct"]
	vent_charge = d["vc"]
	closet_exposed = d["ce"]
	has_gold = d["gold"]
	chips = d["chips"]
	score = d["score"]


func is_in_vent(sim: TurnManager) -> bool:
	return sim.grid.get_tile(grid_pos) == GridManager.TileType.VENT


func is_hidden_in_closet(sim: TurnManager) -> bool:
	return sim.grid.get_tile(grid_pos) == GridManager.TileType.CLOSET and not closet_exposed


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


func _ok(msg: String = "") -> Dictionary:
	return {"ok": true, "msg": msg}


func perform_turn_action(sim: TurnManager, action: Dictionary) -> Dictionary:
	var kind: String = String(action.get("type", "wait"))
	var dir: Vector2i = action.get("dir", Vector2i.ZERO)
	var res: Dictionary
	match kind:
		"wait":
			res = _do_wait(sim)
		"move":
			res = _do_move(sim, dir)
		"dash":
			res = _do_dash(sim, dir)
		"takedown":
			res = _do_takedown(sim)
		"interact":
			res = _do_interact(sim)
		"gadget":
			res = _do_gadget(sim, int(action.get("slot", 0)), action.get("target", grid_pos))
		_:
			res = _fail("Неизвестное действие")
	if res["ok"]:
		if sim.grid.get_tile(grid_pos) != GridManager.TileType.CLOSET:
			closet_exposed = false
		_try_pickpocket(sim)
	return res


func _do_wait(_sim: TurnManager) -> Dictionary:
	vent_charge = NO_CELL
	return _ok()


func _do_move(sim: TurnManager, dir: Vector2i) -> Dictionary:
	if dir == Vector2i.ZERO:
		return _fail("")
	facing = dir
	var target: Vector2i = grid_pos + dir
	var grid: GridManager = sim.grid
	var tile: int = grid.get_tile(target)
	if not grid.is_in_bounds(target) or not grid.is_terrain_open_for_player(target):
		return _fail("")
	if grid.solid_entities.has(target):
		return _fail("Путь перегорожен оборудованием")
	if sim.guard_at(target) != null:
		return _fail("Охранник на пути")
	if tile == GridManager.TileType.DOOR_CLOSED:
		var door: ElectronicDoor = grid.doors.get(target)
		if door == null:
			return _fail("")
		if not door.is_open():
			if door.required_keycard != "" and keycards.has(door.required_keycard):
				door.key_open = true
				sim.add_event({"t": "door_open", "pos": target})
			elif door.required_keycard != "":
				return _fail("Дверь заперта: нужна %s ключ-карта" % TurnManager.card_name(door.required_keycard))
			else:
				return _fail("Дверь обесточена только рубильником — найдите питание")
	if tile == GridManager.TileType.EXTRACTION and sim.alarm.is_alarm():
		return _fail("ТРЕВОГА: шлюз эвакуации заблокирован")
	if tile == GridManager.TileType.VENT and vent_charge != target:
		# В вентиляции тесно: первый ход — подготовка, второй — сдвиг.
		vent_charge = target
		sim.add_event({"t": "vent_prep", "pos": grid_pos})
		return _ok("Протискиваетесь в шахту...")
	var prev: Vector2i = grid_pos
	var was_seen: bool = sim.is_cell_seen(prev)
	vent_charge = NO_CELL
	grid_pos = target
	if tile == GridManager.TileType.CLOSET:
		closet_exposed = was_seen
		if was_seen:
			sim.add_event({"t": "closet_exposed", "pos": target})
	var noise: int = 1
	if tile == GridManager.TileType.VENT or tile == GridManager.TileType.CLOSET:
		noise = 0
	sim.add_event({"t": "step", "from": prev, "to": target})
	if noise > 0:
		sim.add_noise(target, noise)
	_pickup_here(sim)
	return _ok()


func _dash_cell_ok(sim: TurnManager, c: Vector2i, landing: bool) -> bool:
	var grid: GridManager = sim.grid
	if not grid.is_in_bounds(c) or grid.solid_entities.has(c) or sim.guard_at(c) != null:
		return false
	var t: int = grid.get_tile(c)
	if t == GridManager.TileType.EXTRACTION and (sim.alarm.is_alarm() and landing):
		return false
	return t == GridManager.TileType.FLOOR or t == GridManager.TileType.HAZARD \
		or t == GridManager.TileType.EXTRACTION or t == GridManager.TileType.VAULT_FLOOR


func _do_dash(sim: TurnManager, dir: Vector2i) -> Dictionary:
	if dir == Vector2i.ZERO:
		return _fail("")
	facing = dir
	if dash_cd > 0:
		return _fail("Рывок перезаряжается: %d" % dash_cd)
	var c1: Vector2i = grid_pos + dir
	var c2: Vector2i = grid_pos + dir * 2
	if not _dash_cell_ok(sim, c1, false) or not _dash_cell_ok(sim, c2, true):
		return _fail("Для рывка нужны две свободные клетки подряд")
	var prev: Vector2i = grid_pos
	vent_charge = NO_CELL
	grid_pos = c2
	dash_cd = DASH_COOLDOWN
	sim.stats["dash"] = int(sim.stats["dash"]) + 1
	sim.add_event({"t": "dash", "from": prev, "to": c2})
	sim.add_noise(c2, 3)
	_pickup_here(sim)
	return _ok()


func _do_takedown(sim: TurnManager) -> Dictionary:
	var target_cell: Vector2i = grid_pos + facing
	var g: BaseEnemy = sim.guard_at(target_cell)
	if g == null:
		return _fail("Впереди никого нет (F бьёт в сторону взгляда)")
	if not g.can_be_shocked():
		return _fail("Эта цель неуязвима к шокеру — используйте ЭМИ")
	if g.is_stunned():
		return _fail("Уже обезврежен")
	if g.facing != facing:
		return _fail("Бить можно только строго со спины")
	if int(gadgets["shock"]) <= 0:
		return _fail("Шокер разряжен")
	gadgets["shock"] = int(gadgets["shock"]) - 1
	g.stun(6)
	vent_charge = NO_CELL
	sim.add_event({"t": "stun", "pos": g.grid_pos, "id": g.id})
	sim.stats["takedowns"] = int(sim.stats["takedowns"]) + 1
	sim.award_style("ТИХОЕ ОГЛУШЕНИЕ", 100)
	return _ok("Охранник оглушён на 5 ходов")


func _do_interact(sim: TurnManager) -> Dictionary:
	var sw: PowerSwitch = sim.switch_near(grid_pos)
	if sw == null:
		return _fail("Рядом нечего взламывать (рубильник/терминал — на соседней клетке)")
	vent_charge = NO_CELL
	sim.toggle_switch(sw)
	return _ok()


func _do_gadget(sim: TurnManager, slot: int, target: Vector2i) -> Dictionary:
	var key: String = ""
	match slot:
		1: key = "smoke"
		2: key = "decoy"
		3: key = "emp"
		4: key = "cloak"
		_: return _fail("")
	if int(gadgets[key]) <= 0:
		return _fail("Гаджет закончился")
	var dist: int = absi(target.x - grid_pos.x) + absi(target.y - grid_pos.y)
	match key:
		"smoke":
			if dist > 3 or not _throwable(sim, target):
				return _fail("Дымовую шашку можно бросить до 3 клеток")
			sim.deploy_smoke(target)
		"decoy":
			if dist > 4 or not _throwable(sim, target) or dist == 0:
				return _fail("Манок можно бросить до 4 клеток")
			sim.add_event({"t": "decoy", "pos": target})
			sim.add_noise(target, 4, true)
		"emp":
			sim.emp_pulse(grid_pos, 2)
		"cloak":
			if cloak_turns > 0:
				return _fail("Плащ уже активен")
			cloak_turns = 2
			sim.add_event({"t": "cloak", "pos": grid_pos})
	gadgets[key] = int(gadgets[key]) - 1
	sim.stats["gadgets"] = int(sim.stats["gadgets"]) + 1
	vent_charge = NO_CELL
	return _ok()


func _throwable(sim: TurnManager, c: Vector2i) -> bool:
	if not sim.grid.is_in_bounds(c):
		return false
	var t: int = sim.grid.get_tile(c)
	return t != GridManager.TileType.VOID and t != GridManager.TileType.WALL and t != GridManager.TileType.SERVER


func _pickup_here(sim: TurnManager) -> void:
	for item in sim.loot:
		if not item.collected and item.grid_pos == grid_pos:
			item.collected = true
			match item.kind:
				"gold":
					has_gold = true
					score += item.value
					sim.on_gold_taken()
				"chip":
					chips += 1
					score += item.value
				"keycard":
					if not keycards.has(item.color):
						keycards.append(item.color)
				"medkit":
					hp = mini(MAX_HP, hp + 1)
			sim.add_event({"t": "pickup", "kind": item.kind, "pos": item.grid_pos, "name": item.item_name})


# Карманная кража: сосед вне конуса зрения (или оглушён) отдаёт ключ-карту.
func _try_pickpocket(sim: TurnManager) -> void:
	for g in sim.guards:
		if not g.is_active() or g.keycard_color == "":
			continue
		var d: int = absi(g.grid_pos.x - grid_pos.x) + absi(g.grid_pos.y - grid_pos.y)
		if d != 1:
			continue
		if g.state == BaseEnemy.AIState.CHASE:
			continue
		var can_see: bool = false
		if not g.is_stunned():
			var cone: Dictionary = VisionCone2D.compute(g.grid_pos, g.facing, g.view_range(), g.half_angle(), sim.grid)
			can_see = (cone["red"] as Array).has(grid_pos) or (cone["yellow"] as Array).has(grid_pos)
		if can_see:
			continue
		if not keycards.has(g.keycard_color):
			keycards.append(g.keycard_color)
		sim.add_event({"t": "pickpocket", "pos": g.grid_pos, "color": g.keycard_color, "id": g.id})
		sim.stats["pick"] = int(sim.stats["pick"]) + 1
		sim.award_style("КАРМАННИК", 100)
		g.keycard_color = ""
