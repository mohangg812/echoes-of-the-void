# Регрессия: проигрывает сохранённые решения (tests/solutions) и проверяет победу без тревог.
# godot --headless --path . --script res://tests/replay.gd
extends SceneTree


func _init() -> void:
	var bad: int = 0
	var solver: GDScript = load("res://tests/solver.gd") as GDScript
	for i in range(GameState.LEVEL_FILES.size()):
		var path: String = "res://tests/solutions/level_%d.txt" % (i + 1)
		if not FileAccess.file_exists(path):
			print("уровень %d: решения нет" % (i + 1))
			bad += 1
			continue
		var line: String = FileAccess.get_file_as_string(path).strip_edges()
		var sim: TurnManager = LevelLoader.load_file(GameState.LEVEL_FILES[i])
		if sim == null:
			print("уровень %d: ошибка загрузки" % (i + 1))
			bad += 1
			continue
		var n: int = 0
		for tok in line.split(" ", false):
			var r: Dictionary = sim.execute_player_turn(solver.str_to_action(tok))
			if not bool(r["ok"]):
				print("  ход %d (%s) отвергнут: %s" % [n + 1, tok, r["msg"]])
				break
			n += 1
			if sim.result != "":
				break
		var ok: bool = sim.result == "won" and sim.alarm.times_triggered == 0
		print("уровень %d: %s  ходов=%d тревог=%d рейтинг=%s пар=%d" % [i + 1, "OK" if ok else "ПРОВАЛ", sim.turn_number,
			sim.alarm.times_triggered, sim.get_rating(), int(sim.level_data["par_turns"])])
		if not ok:
			bad += 1
	quit(1 if bad > 0 else 0)
