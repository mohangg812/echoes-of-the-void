# Отладка: godot --headless --path . --script res://tests/debug.gd -- <уровень> "R R U W ..."
# Печатает карту с конусами после каждого хода (красные = r, жёлтые = y).
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level: int = int(args[0])
	var seq: PackedStringArray = args[1].split(" ", false) if args.size() > 1 else PackedStringArray()
	var sim: TurnManager = LevelLoader.load_file(GameState.LEVEL_FILES[level - 1])
	print(render(sim))
	var i: int = 0
	for tok in seq:
		var a: Dictionary = load("res://tests/solver.gd").str_to_action(tok)
		var r: Dictionary = sim.execute_player_turn(a)
		i += 1
		print("— ход ", i, " [", tok, "] ok=", r["ok"], " msg=", r["msg"], " alarm=", sim.alarm.state,
			" cd=", sim.alarm.cooldown, " hp=", sim.player.hp, " keys=", sim.player.keycards, " gold=", sim.player.has_gold)
		for e in r["events"]:
			if e["t"] != "step" and e["t"] != "guard_move":
				print("   событие: ", e)
		print(render(sim))
		if sim.result != "":
			print("РЕЗУЛЬТАТ: ", sim.result)
			break
	quit(0)


func render(sim: TurnManager) -> String:
	var rows: Array[String] = []
	for y in range(sim.grid.height):
		var s: String = ""
		for x in range(sim.grid.width):
			var p := Vector2i(x, y)
			var ch: String = " "
			match sim.grid.get_tile(p):
				GridManager.TileType.WALL: ch = "#"
				GridManager.TileType.FLOOR: ch = "."
				GridManager.TileType.HAZARD: ch = "."
				GridManager.TileType.GLASS_WALL: ch = "="
				GridManager.TileType.VENT: ch = "V"
				GridManager.TileType.CLOSET: ch = "C"
				GridManager.TileType.DOOR_CLOSED: ch = "D" if not sim.grid.doors[p].is_open() else "o"
				GridManager.TileType.EXTRACTION: ch = "E"
				GridManager.TileType.VAULT_FLOOR: ch = "G"
				GridManager.TileType.SERVER: ch = "S"
			if sim.laser_cells.has(p): ch = "*"
			if sim.grid.smoke_cells.has(p): ch = "%"
			for g in sim.guards:
				if g.red_cells.has(p): ch = "r"
				elif g.yellow_cells.has(p) and ch != "r": ch = "y"
			for c in sim.cameras:
				if c.red_cells.has(p): ch = "r"
				elif c.yellow_cells.has(p) and ch != "r": ch = "y"
			for t in sim.turrets:
				if t.ray_cells.has(p): ch = "t"
			for it in sim.loot:
				if not it.collected and it.grid_pos == p: ch = "$"
			for g in sim.guards:
				if g.is_active() and g.grid_pos == p:
					ch = ("E" if g.is_elite else "g") if not g.is_stunned() else "z"
			for c in sim.cameras:
				if c.grid_pos == p: ch = "@"
			for t in sim.turrets:
				if t.grid_pos == p: ch = "T"
			for l in sim.lasers:
				if l.grid_pos == p: ch = "L"
			for sw in sim.switches:
				if sw.grid_pos == p: ch = "/"
			if sim.player.grid_pos == p: ch = "P"
			s += ch
		rows.append(s)
	return "\n".join(rows)
