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
	var errors: Array[String] = validate_data(parsed, true)
	if not errors.is_empty():
		for err in errors:
			push_error("LevelLoader (%s): %s" % [path, err])
		return null
	return build(parsed)


static func _is_valid_vec2(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	var arr: Array = v
	if arr.size() != 2:
		return false
	return (typeof(arr[0]) == TYPE_INT or typeof(arr[0]) == TYPE_FLOAT) \
		and (typeof(arr[1]) == TYPE_INT or typeof(arr[1]) == TYPE_FLOAT)


static func _is_valid_grid_pos(v: Variant, w: int, h: int) -> bool:
	if not _is_valid_vec2(v):
		return false
	var arr: Array = v
	var x: int = int(arr[0])
	var y: int = int(arr[1])
	return x >= 0 and x < w and y >= 0 and y < h


static func validate_data(data: Dictionary, require_campaign_fields: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("layout") or typeof(data["layout"]) != TYPE_ARRAY:
		errors.append("отсутствует или некорректен массив 'layout'")
		return errors
	var layout: Array = data["layout"]
	if layout.is_empty():
		errors.append("массив 'layout' пуст")
		return errors

	var w: int = -1
	var h: int = layout.size()
	var has_extraction: bool = false
	var has_vault: bool = false

	for y in range(h):
		if typeof(layout[y]) != TYPE_STRING:
			errors.append("строка layout[%d] не является строкой" % y)
			continue
		var row: String = String(layout[y])
		if row.is_empty():
			errors.append("строка layout[%d] пуста" % y)
			continue
		if w == -1:
			w = row.length()
		elif row.length() != w:
			errors.append("непрямоугольный layout: строка %d имеет длину %d вместо %d" % [y, row.length(), w])
		for x in range(row.length()):
			var ch: String = row[x]
			if not GridManager.CHAR_TO_TILE.has(ch):
				errors.append("неизвестный символ тайла '%s' в (%d, %d)" % [ch, x, y])
			elif ch == "E":
				has_extraction = true
			elif ch == "G":
				has_vault = true

	if require_campaign_fields:
		if not data.has("level_id"):
			errors.append("отсутствует обязательное поле 'level_id'")
		if String(data.get("title", "")).strip_edges().is_empty():
			errors.append("отсутствует или пусто поле 'title'")
		if int(data.get("par_turns", 0)) <= 0:
			errors.append("поле 'par_turns' должно быть больше 0")
		if not has_extraction:
			errors.append("на карте отсутствует точка эвакуации/старта 'E'")
		if not has_vault:
			errors.append("на карте отсутствует цель 'G' (VAULT_FLOOR)")

	if w <= 0:
		return errors

	var entity_pos_keys: Dictionary = {
		"doors": "pos",
		"switches": "pos",
		"secondary_loot": "pos",
		"items": "pos",
		"lasers": "pos",
		"cameras": "pos",
		"turrets": "pos",
		"guards": "start",
	}
	for section in entity_pos_keys:
		if not data.has(section):
			continue
		if typeof(data[section]) != TYPE_ARRAY:
			errors.append("секция '%s' должна быть массивом" % section)
			continue
		var pos_key: String = String(entity_pos_keys[section])
		var items: Array = data[section]
		for idx in range(items.size()):
			if typeof(items[idx]) != TYPE_DICTIONARY:
				errors.append("%s[%d] не является объектом" % [section, idx])
				continue
			var item: Dictionary = items[idx]
			if not _is_valid_grid_pos(item.get(pos_key), w, h):
				errors.append("%s[%d].%s вне границ карты (%dx%d) или некорректно" % [section, idx, pos_key, w, h])
			if section == "switches" and not item.has("target_group_id"):
				errors.append("switches[%d] не содержит 'target_group_id'" % idx)
			elif section == "items" and not item.has("kind"):
				errors.append("items[%d] не содержит 'kind'" % idx)
			elif section == "lasers" and not _is_valid_vec2(item.get("dir")):
				errors.append("lasers[%d] не содержит корректный вектор 'dir'" % idx)
			elif section == "cameras" and not _is_valid_vec2(item.get("initial_facing")):
				errors.append("cameras[%d] не содержит корректный вектор 'initial_facing'" % idx)
			elif section == "guards" and item.has("waypoints"):
				if typeof(item["waypoints"]) != TYPE_ARRAY:
					errors.append("guards[%d].waypoints должен быть массивом" % idx)
				else:
					var wps: Array = item["waypoints"]
					for wi in range(wps.size()):
						if not _is_valid_grid_pos(wps[wi], w, h):
							errors.append("guards[%d].waypoints[%d] вне границ карты" % [idx, wi])

	return errors


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
	var errors: Array[String] = validate_data(data, false)
	if not errors.is_empty():
		for err in errors:
			push_error("LevelLoader: %s" % err)
		return null
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
