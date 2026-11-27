class_name LevelSchema
extends RefCounted

const POS_FIELDS := {
	"guards": "start", "cameras": "pos", "lasers": "pos", "switches": "pos",
	"doors": "pos", "secondary_loot": "pos", "turrets": "pos", "items": "pos",
}
const CARDS := ["", "RED", "BLUE", "YELLOW"]


static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and value >= low and value <= high and floor(value) == value


static func point(value: Variant, w: int, h: int) -> bool:
	return value is Array and value.size() == 2 and integer(value[0], 0, w - 1) and integer(value[1], 0, h - 1)


static func direction(value: Variant) -> bool:
	return value is Array and value.size() == 2 and integer(value[0], -1, 1) \
		and integer(value[1], -1, 1) and abs(value[0]) + abs(value[1]) == 1


static func cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not integer(data.get("level_id"), 1, 999):
		errors.append("level_id: ожидается целое число 1–999")
	if not integer(data.get("par_turns"), 1, 10000):
		errors.append("par_turns: ожидается целое число 1–10000")
	if not (data.get("title") is String) or not (data.get("subtitle") is String):
		errors.append("title и subtitle: ожидаются строки")
	for key in ["briefing", "intro"]:
		if data.has(key) and not _lines_valid(data[key], key == "intro"):
			errors.append("%s: неверный формат реплик" % key)
	if data.has("lines"):
		if not (data["lines"] is Dictionary):
			errors.append("lines: ожидается объект")
		else:
			for key: String in data["lines"]:
				if not _lines_valid(data["lines"][key], true):
					errors.append("lines.%s: неверный формат реплик" % key)
	var gadgets: Variant = data.get("starting_gadgets")
	if not (gadgets is Dictionary):
		errors.append("starting_gadgets: ожидается объект")
	else:
		for key in ["smoke", "decoy", "emp", "cloak", "shock"]:
			if not integer(gadgets.get(key, 1 if key == "shock" else null), 0, 99):
				errors.append("starting_gadgets.%s: ожидается целое число 0–99" % key)
	var layout: Variant = data.get("layout")
	if not (layout is Array) or layout.is_empty() or layout.size() > 25 \
			or not (layout[0] is String) or layout[0].is_empty() or layout[0].length() > 40:
		errors.append("layout: ожидается матрица от 1×1 до 40×25")
		return errors
	var h: int = layout.size()
	var w: int = layout[0].length()
	var exits: Array[Vector2i] = []
	var vaults: Array[Vector2i] = []
	var layout_doors: Dictionary = {}
	for y in range(h):
		if not (layout[y] is String) or layout[y].length() != w:
			errors.append("layout[%d]: ожидается строка длиной %d" % [y, w])
			continue
		var row: String = layout[y]
		for x in range(w):
			var c: Vector2i = Vector2i(x, y)
			match row[x]:
				"E": exits.append(c)
				"G": vaults.append(c)
				"D": layout_doors[c] = true
			if not GridManager.CHAR_TO_TILE.has(row[x]):
				errors.append("layout[%d][%d]: неизвестный символ «%s»" % [y, x, row[x]])
	if exits.size() != 1 or vaults.size() != 1:
		errors.append("layout: нужна ровно одна клетка E и одна G")

	var protected_cells: Dictionary = {}
	var door_cells: Dictionary = {}
	var solids: Dictionary = {}
	var groups: Dictionary = {}
	var targets: Array[String] = []
	for kind: String in POS_FIELDS:
		var entries: Variant = data.get(kind, [] if kind in ["turrets", "items"] else null)
		if not (entries is Array):
			errors.append("%s: ожидается массив" % kind)
			continue
		for i in range(entries.size()):
			var entry: Variant = entries[i]
			var label: String = "%s[%d]" % [kind, i]
			if not (entry is Dictionary):
				errors.append("%s: ожидается объект" % label)
				continue
			var p: Variant = entry.get(POS_FIELDS[kind])
			if not point(p, w, h):
				errors.append("%s: координаты за пределами карты или неверного формата" % label)
				continue
			var c: Vector2i = cell(p)
			_validate_entry(kind, entry, label, w, h, errors)
			if kind in ["guards", "doors", "switches", "turrets"]:
				if protected_cells.has(c):
					errors.append("%s: конфликт позиций с %s" % [label, protected_cells[c]])
				protected_cells[c] = label
			if kind == "doors":
				door_cells[c] = true
				if not layout_doors.has(c):
					errors.append("%s: в layout на позиции двери должен быть символ D" % label)
				if entry.get("required_keycard", "") == "" and entry.get("group_id", "") == "":
					errors.append("%s: дверь без ключ-карты или группы не открывается" % label)
			if kind in ["switches", "turrets"]:
				solids[c] = true
			if kind == "switches" and entry.get("target_group_id") is String:
				targets.append(entry["target_group_id"])
			var group: Variant = entry.get("group_id", "")
			if kind in ["doors", "lasers", "cameras", "turrets"] and group is String and group != "":
				groups[group] = true
	for c: Vector2i in layout_doors:
		if not door_cells.has(c):
			errors.append("layout: дверь %s не описана в doors" % str(c))
	for target in targets:
		if not groups.has(target):
			errors.append("switches: группа «%s» не найдена" % target)
	for c in exits + vaults:
		if solids.has(c):
			errors.append("layout: клетка старта или цели %s занята оборудованием" % str(c))
	if errors.is_empty():
		var reached: Dictionary = _reach(layout, w, h, exits[0], solids)
		if not reached.has(vaults[0]):
			errors.append("layout: от эвакуации нет маршрута к ядру даже при открытых дверях")
		for kind in ["secondary_loot", "items"]:
			for entry: Dictionary in data.get(kind, []):
				if not reached.has(cell(entry["pos"])):
					errors.append("%s: недостижимый предмет %s" % [kind, str(entry["pos"])])
		for entry: Dictionary in data["switches"]:
			var accessible: bool = false
			for d in GridManager.DIRS:
				accessible = accessible or reached.has(cell(entry["pos"]) + d)
			if not accessible:
				errors.append("switches: нет доступной соседней клетки у %s" % str(entry["pos"]))
	return errors


static func _lines_valid(value: Variant, dialogue: bool) -> bool:
	if not (value is Array):
		return false
	for line: Variant in value:
		if dialogue:
			if not (line is Array) or line.size() != 2 or not (line[0] is String) or not (line[1] is String):
				return false
		elif not (line is String):
			return false
	return true


static func _validate_entry(kind: String, e: Dictionary, label: String, w: int, h: int, errors: PackedStringArray) -> void:
	for key in ["group_id", "description", "name"]:
		if e.has(key) and not (e[key] is String):
			errors.append("%s.%s: ожидается строка" % [label, key])
	for key in ["ping_pong", "dormant", "scan", "climax", "activate_on_loot"]:
		if e.has(key) and not (e[key] is bool):
			errors.append("%s.%s: ожидается логическое значение" % [label, key])
	for key in ["required_keycard", "keycard", "color"]:
		if e.has(key) and e[key] not in CARDS:
			errors.append("%s.%s: неизвестный цвет" % [label, key])
	var limits := {"period": 1, "range": 1, "on_turns": 1, "off_turns": 0, "phase": 0, "value": 0, "wait": 0}
	for key: String in limits:
		if e.has(key) and not integer(e[key], limits[key], 10000):
			errors.append("%s.%s: число вне допустимого диапазона" % [label, key])
	for key in ["facing", "initial_facing", "dir"]:
		if (e.has(key) or (key == "initial_facing" and kind == "cameras") \
				or (key == "dir" and kind == "lasers")) and not direction(e.get(key)):
			errors.append("%s.%s: ожидается ортогональное направление" % [label, key])
	for key in ["waypoints", "facings"]:
		if e.has(key):
			if not (e[key] is Array):
				errors.append("%s.%s: ожидается массив" % [label, key])
			else:
				for v: Variant in e[key]:
					if not (point(v, w, h) if key == "waypoints" else direction(v)):
						errors.append("%s.%s: неверная координата или направление" % [label, key])
	match kind:
		"guards":
			if e.get("type", "standard") not in ["standard", "elite", "hound", "drone"]:
				errors.append("%s.type: неизвестный тип охраны" % label)
		"cameras":
			if e.get("rotation_mode", "cw_90") not in ["fixed", "cw_90", "ccw_90", "swing"]:
				errors.append("%s.rotation_mode: неизвестный режим" % label)
		"switches":
			if not (e.get("target_group_id") is String) or e["target_group_id"] == "":
				errors.append("%s.target_group_id: требуется непустая строка" % label)
			if e.get("kind", "switch") not in ["switch", "terminal"]:
				errors.append("%s.kind: неизвестное устройство" % label)
		"items":
			if e.get("kind") not in ["keycard", "medkit"]:
				errors.append("%s.kind: неизвестный предмет" % label)
			if e.get("kind") == "keycard" and e.get("color", "") == "":
				errors.append("%s.color: карта должна иметь цвет" % label)


static func _reach(layout: Array, w: int, h: int, start: Vector2i, solids: Dictionary) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in GridManager.DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.x >= w or n.y < 0 or n.y >= h or seen.has(n) or solids.has(n):
				continue
			var row: String = layout[n.y]
			if row[n.x] not in [" ", "#", "=", "S"]:
				seen[n] = true
				queue.append(n)
	return seen
