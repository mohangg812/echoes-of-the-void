# res://levels/LevelLoader.gd
# Собирает мир (TurnManager) из JSON-схемы: ASCII-матрица layout + типизированные массивы объектов.
class_name LevelLoader
extends RefCounted


static func load_file(path: String) -> TurnManager:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LevelLoader: не открыть %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("LevelLoader: битый JSON %s" % path)
		return null
	return build(parsed)


static func _v2(a: Variant) -> Vector2i:
	var arr: Array = a
	return Vector2i(int(arr[0]), int(arr[1]))


static func _facing_sequence(initial: Vector2i, mode: String, custom: Array) -> Array[Vector2i]:
	var seq: Array[Vector2i] = []
	if custom.size() > 0:
		for v in custom:
			seq.append(_v2(v))
		return seq
	match mode:
		"cw_90":
			var d: Vector2i = initial
			for _i in range(4):
				seq.append(d)
				d = GridManager.rot_cw(d)
		"ccw_90":
			var d2: Vector2i = initial
			for _i in range(4):
				seq.append(d2)
				d2 = GridManager.rot_ccw(d2)
		"swing":
			seq = [initial, GridManager.rot_cw(initial), initial, GridManager.rot_ccw(initial)]
		_:
			seq = [initial]
	return seq


static func build(data: Dictionary) -> TurnManager:
	var sim: TurnManager = TurnManager.new()
	sim.level_data = data
	var layout: Array = data["layout"]
	sim.grid.load_layout(layout)
	var grid: GridManager = sim.grid
	var start_found: bool = false
	var gold_cell: Vector2i = Vector2i(-1, -1)
	for y in range(grid.height):
		for x in range(grid.width):
			var t: int = grid.get_tile(Vector2i(x, y))
			if t == GridManager.TileType.EXTRACTION and not start_found:
				sim.player.grid_pos = Vector2i(x, y)
				start_found = true
			elif t == GridManager.TileType.VAULT_FLOOR:
				gold_cell = Vector2i(x, y)
	sim.player.start_grid_pos = sim.player.grid_pos
	sim.player.facing = Vector2i(1, 0)
	var sg: Dictionary = data.get("starting_gadgets", {})
	sim.player.gadgets = {
		"smoke": int(sg.get("smoke", 0)), "decoy": int(sg.get("decoy", 0)),
		"emp": int(sg.get("emp", 0)), "cloak": int(sg.get("cloak", 0)),
		"shock": int(sg.get("shock", 1)),
	}

	# Золото
	if gold_cell.x >= 0:
		var gold: LootItem = LootItem.new()
		gold.id = "gold"
		gold.kind = "gold"
		gold.grid_pos = gold_cell
		gold.value = 2000
		gold.item_name = "Ядро Данных"
		sim.loot.append(gold)
	# Двери
	var di: int = 0
	for d in data.get("doors", []):
		var door: ElectronicDoor = ElectronicDoor.new()
		door.id = "door%d" % di
		di += 1
		door.grid_pos = _v2(d["pos"])
		door.required_keycard = String(d.get("required_keycard", ""))
		door.group_id = String(d.get("group_id", ""))
		grid.set_tile(door.grid_pos, GridManager.TileType.DOOR_CLOSED)
		grid.doors[door.grid_pos] = door
		sim.doors.append(door)
	# Рубильники и терминалы
	var si: int = 0
	for s in data.get("switches", []):
		var sw: PowerSwitch = PowerSwitch.new()
		sw.id = "sw%d" % si
		si += 1
		sw.grid_pos = _v2(s["pos"])
		sw.target_group_id = String(s["target_group_id"])
		sw.description = String(s.get("description", ""))
		sw.kind = String(s.get("kind", "switch"))
		grid.solid_entities[sw.grid_pos] = true
		sim.switches.append(sw)
	# Лут
	var li: int = 0
	for l in data.get("secondary_loot", []):
		var it: LootItem = LootItem.new()
		it.id = "chip%d" % li
		li += 1
		it.kind = "chip"
		it.grid_pos = _v2(l["pos"])
		it.value = int(l.get("value", 500))
		it.item_name = String(l.get("name", "Чип"))
		sim.loot.append(it)
		sim.chips_total += 1
	var ii: int = 0
	for l in data.get("items", []):
		var it2: LootItem = LootItem.new()
		it2.id = "item%d" % ii
		ii += 1
		it2.kind = String(l["kind"])
		it2.grid_pos = _v2(l["pos"])
		it2.color = String(l.get("color", ""))
		it2.item_name = String(l.get("name", ""))
		sim.loot.append(it2)
	# Лазеры
	var lai: int = 0
	for l in data.get("lasers", []):
		var las: LaserEmitter = LaserEmitter.new()
		las.id = "laser%d" % lai
		lai += 1
		las.grid_pos = _v2(l["pos"])
		las.facing = _v2(l["dir"])
		las.on_turns = int(l.get("on_turns", 1))
		las.off_turns = int(l.get("off_turns", 1))
		las.phase = int(l.get("phase", 0))
		las.group_id = String(l.get("group_id", ""))
		las.activate_on_loot = bool(l.get("activate_on_loot", false))
		las.enabled = not las.activate_on_loot
		sim.lasers.append(las)
	# Камеры
	var ci: int = 0
	for c in data.get("cameras", []):
		var cam: SecurityCamera = SecurityCamera.new()
		cam.id = "cam%d" % ci
		ci += 1
		cam.grid_pos = _v2(c["pos"])
		var init_f: Vector2i = _v2(c["initial_facing"])
		cam.facing_sequence = _facing_sequence(init_f, String(c.get("rotation_mode", "cw_90")), c.get("facings", []))
		cam.facing = cam.facing_sequence[0]
		cam.period = int(c.get("period", 1))
		cam.group_id = String(c.get("group_id", ""))
		cam.base_range = int(c.get("range", 5))
		sim.cameras.append(cam)
	# Турели
	var ti: int = 0
	for t in data.get("turrets", []):
		var tur: SentryTurret = SentryTurret.new()
		tur.id = "turret%d" % ti
		ti += 1
		tur.grid_pos = _v2(t["pos"])
		tur.facing = _v2(t.get("facing", [1, 0]))
		tur.group_id = String(t.get("group_id", ""))
		tur.climax = bool(t.get("climax", false))
		grid.solid_entities[tur.grid_pos] = true
		sim.turrets.append(tur)
	# Охрана
	var gi: int = 0
	for g in data.get("guards", []):
		var guard: BaseEnemy = BaseEnemy.new()
		guard.id = "guard%d" % gi
		gi += 1
		guard.kind = String(g.get("type", "standard"))
		guard.is_elite = guard.kind == "elite"
		guard.grid_pos = _v2(g["start"])
		guard.start_grid_pos = guard.grid_pos
		guard.facing = _v2(g.get("facing", [1, 0]))
		for w in g.get("waypoints", []):
			guard.patrol_waypoints.append(_v2(w))
		guard.ping_pong = bool(g.get("ping_pong", true))
		guard.keycard_color = String(g.get("keycard", ""))
		guard.dormant = bool(g.get("dormant", false))
		guard.scan = bool(g.get("scan", false))
		guard.wait_at_wp = int(g.get("wait", 0))
		sim.guards.append(guard)
		if not guard.dormant:
			grid.guard_cells[guard.grid_pos] = true

	grid.rebuild_navigation_solids()
	sim.refresh_vision()
	for t in sim.turrets:
		t.update_lock(sim)
	return sim
