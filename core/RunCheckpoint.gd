class_name RunCheckpoint
extends RefCounted

const PATH: String = "user://run.json"
const VERSION: int = 1


static func read(path: String = PATH) -> Dictionary:
	var data: Variant = LocalSave.read_json(path)
	if not (data is Dictionary) or data.get("version") != VERSION:
		return {}
	if not LevelSchema.integer(data.get("level"), 0, GameState.LEVEL_FILES.size() - 1) \
			or not (data.get("map_hash") is String) or not (data.get("actions") is Array) \
			or data["actions"].size() > 20000:
		return {}
	if not LevelSchema.integer(data.get("undos"), 0, 1000000):
		return {}
	return data


static func store(level: int, actions: Array, undos: int, path: String = PATH) -> Error:
	if actions.size() > 20000:
		return ERR_OUT_OF_MEMORY
	return LocalSave.replace_json(path, {
		"version": VERSION, "level": level, "map_hash": map_hash(level),
		"actions": actions, "undos": undos,
	})


static func map_hash(level: int) -> String:
	return FileAccess.get_file_as_string(GameState.LEVEL_FILES[level]).sha256_text()


static func pack_action(action: Dictionary) -> Dictionary:
	var out: Dictionary = {"type": action["type"]}
	for key in ["dir", "target"]:
		if action.has(key):
			var c: Vector2i = action[key]
			out[key] = [c.x, c.y]
	if action.has("slot"):
		out["slot"] = action["slot"]
	return out


static func restore(checkpoint: Dictionary, level: int, level_data: Dictionary) -> TurnManager:
	if checkpoint.is_empty() or checkpoint.get("level") != level or checkpoint.get("map_hash") != map_hash(level):
		return null
	var simulation: TurnManager = LevelLoader.build(level_data)
	for stored: Variant in checkpoint["actions"]:
		var action: Dictionary = _unpack_action(stored, simulation)
		if action.is_empty() or not simulation.execute_player_turn(action)["ok"] or simulation.result != "":
			return null
	simulation.undo_count = int(checkpoint["undos"])
	return simulation


static func _unpack_action(stored: Variant, simulation: TurnManager) -> Dictionary:
	if not (stored is Dictionary):
		return {}
	match stored.get("type"):
		"move", "dash":
			if LevelSchema.direction(stored.get("dir")):
				return {"type": stored["type"], "dir": LevelSchema.cell(stored["dir"])}
		"gadget":
			if LevelSchema.integer(stored.get("slot"), 1, 4) and LevelSchema.point(
					stored.get("target"), simulation.grid.width, simulation.grid.height):
				return {"type": "gadget", "slot": int(stored["slot"]), "target": LevelSchema.cell(stored["target"])}
		"wait", "interact", "takedown":
			return {"type": stored["type"]}
	return {}
