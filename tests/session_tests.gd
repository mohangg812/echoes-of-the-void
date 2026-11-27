extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", label)


func _run() -> void:
	var game: Node = load("res://levels/MainGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var simulation: TurnManager = game.get("sim")
	var sfx: Node = root.get_node("ProceduralSFX")
	var siren: AudioStreamPlayer = sfx.get("_siren")
	var music: AudioStreamPlayer = sfx.get("_music")
	for bus in ["Master", "SFX", "Ambience", "AlarmSiren"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "audio bus: " + bus)
	_check(siren.bus == &"AlarmSiren" and music.bus == &"Ambience", "looping streams routed")
	if simulation != null:
		simulation.trigger_alarm(simulation.player.grid_pos, "тест")
		game.call("_sync_views", false)
		_check(siren.playing, "siren starts")
		# Имитируем перезагрузку уровня без удаления реального run.json пользователя.
		game.call("_load_level", false)
		simulation = game.get("sim")
		_check(not siren.playing and not simulation.alarm.is_alarm(), "siren stops on level reload")
	else:
		_check(false, "mission loaded")
	var modal: CanvasLayer = game.get("modal")
	modal.call("show_settings")
	_check(modal.get("is_open") and is_instance_valid(modal.get("_binding_action")), "settings opens")
	game.set("level_index", -1)
	_check(not game.call("_load_level", false), "invalid mission index rejected")
	_check(modal.get("is_open"), "load failure opens modal")
	sfx.call("stop_music")
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("session checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures else 0)
