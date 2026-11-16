# Решатель уровней (лучевой поиск по настоящей симуляции) — доказывает, что уровень проходим.
# Запуск:  godot --headless --path . --script res://tests/solver.gd -- <уровень 1..5> [strict] [gadgets] [beam=N] [depth=N]
#   strict  — запретить любую тревогу (чисто стелс-прохождение)
#   gadgets — разрешить гаджеты (дым/манок/ЭМИ/плащ) в переборе
# Решение пишется в tests/solutions/level_N.txt и проигрывается tests/replay.gd.
extends SceneTree

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const DIR_CH: String = "UDLR"

var sim: TurnManager
var strict: bool = false
var use_gadgets: bool = false
var staged: bool = false
var gold_cell: Vector2i
var start_cell: Vector2i


func _init() -> void:
	var level: int = 1
	var beam: int = 160
	var depth: int = 160
	for a in OS.get_cmdline_user_args():
		if a == "strict": strict = true
		elif a == "gadgets": use_gadgets = true
		elif a == "staged": staged = true
		elif a.begins_with("beam="): beam = int(a.substr(5))
		elif a.begins_with("depth="): depth = int(a.substr(6))
		else: level = int(a)
	var path: String = GameState.LEVEL_FILES[level - 1]
	sim = LevelLoader.load_file(path)
	for it in sim.loot:
		if it.kind == "gold":
			gold_cell = it.grid_pos
	start_cell = sim.player.start_grid_pos
	print("Уровень ", level, " strict=", strict, " gadgets=", use_gadgets, " beam=", beam)
	var t0: int = Time.get_ticks_msec()
	var sol: Array = []
	if staged:
		sol = _run_staged(beam, depth)
	else:
		sol = _search(beam, depth, {})
	print("время: ", (Time.get_ticks_msec() - t0) / 1000.0, " c")
	if sol.is_empty():
		print("РЕШЕНИЕ НЕ НАЙДЕНО")
		quit(2)
		return
	var line: String = " ".join(PackedStringArray(sol.map(func(a: Dictionary) -> String: return action_to_str(a))))
	print("РЕШЕНИЕ (", sol.size(), " ходов): ", line)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/solutions"))
	var f: FileAccess = FileAccess.open("res://tests/solutions/level_%d%s.txt" % [level, "" if strict else "_loud"], FileAccess.WRITE)
	f.store_string(line)
	f.close()
	quit(0)


static func action_to_str(a: Dictionary) -> String:
	match String(a["type"]):
		"wait": return "W"
		"move": return _dir_ch(a["dir"], false)
		"dash": return _dir_ch(a["dir"], true)
		"takedown": return "F"
		"interact": return "E"
		"gadget":
			var t: Vector2i = a.get("target", Vector2i.ZERO)
			return "%d@%d,%d" % [int(a["slot"]), t.x, t.y]
	return "?"


static func _dir_ch(d: Vector2i, lower: bool) -> String:
	var ch: String = "U"
	if d == Vector2i(0, 1): ch = "D"
	elif d == Vector2i(-1, 0): ch = "L"
	elif d == Vector2i(1, 0): ch = "R"
	return ch.to_lower() if lower else ch


static func str_to_action(tok: String) -> Dictionary:
	match tok:
		"W": return {"type": "wait"}
		"F": return {"type": "takedown"}
		"E": return {"type": "interact"}
		"U": return {"type": "move", "dir": Vector2i(0, -1)}
		"D": return {"type": "move", "dir": Vector2i(0, 1)}
		"L": return {"type": "move", "dir": Vector2i(-1, 0)}
		"R": return {"type": "move", "dir": Vector2i(1, 0)}
		"u": return {"type": "dash", "dir": Vector2i(0, -1)}
		"d": return {"type": "dash", "dir": Vector2i(0, 1)}
		"l": return {"type": "dash", "dir": Vector2i(-1, 0)}
		"r": return {"type": "dash", "dir": Vector2i(1, 0)}
	if "@" in tok:
		var p: PackedStringArray = tok.split("@")
		var xy: PackedStringArray = p[1].split(",")
		return {"type": "gadget", "slot": int(p[0]), "target": Vector2i(int(xy[0]), int(xy[1]))}
	return {"type": "wait"}


func _candidate_actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in DIRS:
		out.append({"type": "move", "dir": d})
	out.append({"type": "wait"})
	for d in DIRS:
		out.append({"type": "dash", "dir": d})
	out.append({"type": "takedown"})
	out.append({"type": "interact"})
	if use_gadgets:
		var p: Vector2i = sim.player.grid_pos
		for d in DIRS:
			out.append({"type": "gadget", "slot": 1, "target": p + d * 2})
			out.append({"type": "gadget", "slot": 1, "target": p + d * 3})
			out.append({"type": "gadget", "slot": 2, "target": p + d * 3})
			out.append({"type": "gadget", "slot": 2, "target": p + d * 4})
		out.append({"type": "gadget", "slot": 3, "target": p})
		out.append({"type": "gadget", "slot": 4, "target": p})
	return out


func _bfs(from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var q: Array[Vector2i] = [from]
	var head: int = 0
	var g: GridManager = sim.grid
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in GridManager.DIRS:
			var n: Vector2i = c + d
			if dist.has(n) or not g.is_in_bounds(n):
				continue
			if not g.is_walkable_for_player(n, sim.player.keycards):
				continue
			dist[n] = int(dist[c]) + 1
			q.append(n)
	return dist


func _heuristic() -> float:
	if sim.result == "won":
		return 0.0
	var dist: Dictionary = _bfs(sim.player.grid_pos)
	var h: float = 999.0
	var target: Vector2i = start_cell if sim.player.has_gold else gold_cell
	if dist.has(target):
		h = float(dist[target]) + (0.0 if sim.player.has_gold else 100.0)
	else:
		# нужна ключ-карта или рубильник
		var best: float = 999.0
		for d in sim.doors:
			if d.is_open():
				continue
			if d.required_keycard != "" and not sim.player.keycards.has(d.required_keycard):
				for g in sim.guards:
					if g.keycard_color == d.required_keycard:
						for nb in GridManager.DIRS:
							var c: Vector2i = g.grid_pos + nb
							if dist.has(c):
								best = minf(best, float(dist[c]) + 40.0)
				for it in sim.loot:
					if it.kind == "keycard" and it.color == d.required_keycard and not it.collected and dist.has(it.grid_pos):
						best = minf(best, float(dist[it.grid_pos]) + 40.0)
			elif d.group_id != "":
				for sw in sim.switches:
					if sw.target_group_id == d.group_id and not sw.on:
						for nb in GridManager.DIRS:
							var c2: Vector2i = sw.grid_pos + nb
							if dist.has(c2):
								best = minf(best, float(dist[c2]) + 40.0)
		h = best + 200.0
	if sim.alarm.is_alarm():
		h += 6.0
	h += float(sim.hp_lost) * 12.0
	h += float(sim.alarm.times_triggered) * 12.0
	return h


func _stages() -> Array:
	var st: Array = []
	var seen: Dictionary = {}
	for d in sim.doors:
		if d.required_keycard != "" and not seen.has(d.required_keycard):
			seen[d.required_keycard] = true
			st.append({"type": "card", "color": d.required_keycard})
	st.append({"type": "gold"})
	st.append({"type": "exit"})
	return st


func _stage_done(stage: Dictionary) -> bool:
	match String(stage["type"]):
		"card": return sim.player.keycards.has(String(stage["color"]))
		"gold": return sim.player.has_gold
	return sim.result == "won"


func _run_staged(beam: int, depth: int) -> Array:
	var all: Array = []
	var snap: Dictionary = sim.snapshot()
	for stage in _stages():
		print("ЭТАП: ", stage)
		sim.restore(snap)
		var res: Array = _search(beam, depth, stage)
		if res.is_empty():
			return []
		# проигрываем найденное, чтобы получить конечное состояние этапа
		sim.restore(snap)
		for a in res:
			sim.execute_player_turn(a)
		all.append_array(res)
		print("  этап ок: ", " ".join(PackedStringArray(res.map(func(a: Dictionary) -> String: return action_to_str(a)))))
		snap = sim.snapshot()
	return all


func _stage_h(stage: Dictionary) -> float:
	var dist: Dictionary = _bfs(sim.player.grid_pos)
	var h: float = 500.0
	match String(stage["type"]):
		"card":
			for g in sim.guards:
				if g.is_active() and g.keycard_color == String(stage["color"]):
					for nb in GridManager.DIRS:
						var c: Vector2i = g.grid_pos + nb
						if dist.has(c):
							h = minf(h, float(dist[c]))
		"gold":
			if dist.has(gold_cell):
				h = float(dist[gold_cell])
		"exit":
			if dist.has(start_cell):
				h = float(dist[start_cell])
	h += float(sim.hp_lost) * 12.0 + float(sim.alarm.times_triggered) * 12.0
	if sim.alarm.is_alarm():
		h += 6.0
	return h


func _search(beam: int, depth: int, stage: Dictionary) -> Array:
	var root: Dictionary = {"snap": sim.snapshot(), "acts": [], "f": 0.0}
	var frontier: Array = [root]
	var seen: Dictionary = {}
	var level_best: float = 1e9
	for step in range(depth):
		var children: Array = []
		for node in frontier:
			sim.restore(node["snap"])
			sim.history.clear()
			var base_snap: Dictionary = node["snap"]
			for a in _candidate_actions():
				sim.restore(base_snap)
				var r: Dictionary = sim.execute_player_turn(a)
				if not bool(r["ok"]):
					continue
				if sim.result == "lost":
					continue
				if strict and sim.alarm.times_triggered > 0:
					continue
				if sim.result == "won" or (not stage.is_empty() and _stage_done(stage)):
					var acts: Array = (node["acts"] as Array).duplicate()
					acts.append(a)
					return acts
				var s: Dictionary = sim.snapshot()
				var key: int = s.hash()
				if seen.has(key):
					continue
				seen[key] = true
				var acts2: Array = (node["acts"] as Array).duplicate()
				acts2.append(a)
				children.append({"snap": s, "acts": acts2, "f": (_heuristic() if stage.is_empty() else _stage_h(stage)) + 0.25 * float(step)})
		if children.is_empty():
			return []
		children.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["f"]) < float(y["f"]))
		if children.size() > beam:
			children.resize(beam)
		frontier = children
		if step % 10 == 0:
			print("  шаг ", step, " лучший f=", children[0]["f"], " узлов=", children.size())
		if step == depth - 1 or step % 40 == 39:
			var l: String = " ".join(PackedStringArray((children[0]["acts"] as Array).map(func(a: Dictionary) -> String: return action_to_str(a))))
			print("  лучшая цепочка на шаге ", step, ": ", l)
	return []
