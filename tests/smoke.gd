# Запуск: godot --headless --path . --script res://tests/smoke.gd
# Проверяет, что все уровни грузятся, рисует ASCII и гоняет несколько ходов.
extends SceneTree

const LEVELS: Array[String] = [
	"res://levels/campaign/level_01_training.json",
	"res://levels/campaign/level_02_laser_hall.json",
	"res://levels/campaign/level_03_vent_network.json",
	"res://levels/campaign/level_04_elite_sector.json",
	"res://levels/campaign/level_05_central_vault.json",
]


func ascii(sim: TurnManager) -> String:
	var rows: Array[String] = []
	for y in range(sim.grid.height):
		var s: String = ""
		for x in range(sim.grid.width):
			var p := Vector2i(x, y)
			var ch: String = "."
			match sim.grid.get_tile(p):
				GridManager.TileType.WALL: ch = "#"
				GridManager.TileType.VOID: ch = " "
				GridManager.TileType.GLASS_WALL: ch = "="
				GridManager.TileType.VENT: ch = "V"
				GridManager.TileType.CLOSET: ch = "C"
				GridManager.TileType.DOOR_CLOSED: ch = "D"
				GridManager.TileType.EXTRACTION: ch = "E"
				GridManager.TileType.VAULT_FLOOR: ch = "G"
				GridManager.TileType.SERVER: ch = "S"
			for g in sim.guards:
				if g.is_active() and g.grid_pos == p: ch = "e" if g.is_elite else "g"
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


func _init() -> void:
	var failed: bool = false
	for path in LEVELS:
		if not FileAccess.file_exists(path):
			print("MISSING ", path)
			continue
		var sim: TurnManager = LevelLoader.load_file(path)
		if sim == null:
			print("LOAD FAILED ", path)
			failed = true
			continue
		print("== ", path, "  ", sim.grid.width, "x", sim.grid.height, "  guards=", sim.guards.size(),
			" cams=", sim.cameras.size(), " lasers=", sim.lasers.size(), " turrets=", sim.turrets.size())
		print(ascii(sim))
		for i in range(6):
			var r: Dictionary = sim.execute_player_turn({"type": "wait"})
			if not r["ok"]:
				print("wait failed")
		var pv: Dictionary = sim.compute_preview()
		print("turn=", sim.turn_number, " alarm=", sim.alarm.state, " preview guards=", pv["guards"].size())
	quit(1 if failed else 0)
