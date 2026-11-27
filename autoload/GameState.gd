# res://autoload/GameState.gd
# Прогресс кампании, выбранный уровень, лучшие результаты. Сохраняется в user://progress.json.
extends Node

const LEVEL_FILES: Array[String] = [
	"res://levels/campaign/level_01_training.json",
	"res://levels/campaign/level_02_laser_hall.json",
	"res://levels/campaign/level_03_vent_network.json",
	"res://levels/campaign/level_04_elite_sector.json",
	"res://levels/campaign/level_05_central_vault.json",
	"res://levels/campaign/level_06_cyber_kennel.json",
	"res://levels/campaign/level_07_ai_core.json",
]
const ACHIEVEMENTS: Dictionary = {
	"ghost": ["ПРИЗРАК", "Пройти миссию без единой тревоги"],
	"collector": ["СОБИРАТЕЛЬ", "Собрать все чипы на уровне"],
	"speed": ["СКОРОСТНИК", "Уложиться в пар-время"],
	"untouched": ["НЕПРИКОСНОВЕННЫЙ", "Пройти миссию, не потеряв щит"],
	"minimal": ["ЧИСТЫЕ РУКИ", "Пройти миссию без единого гаджета"],
	"thief": ["МАСТЕР-ВОР", "Украсть 2 ключ-карты за одну миссию"],
	"perfect": ["ПЕРФЕКЦИОНИСТ", "Получить ранг S"],
	"survivor": ["ЖИВУЧИЙ", "Выиграть миссию после тревоги"],
	"showman": ["ШОУМЕН", "Набрать множитель стиля x4"],
	"legend": ["ЛЕГЕНДА", "Пройти все миссии"],
}
const SAVE_PATH: String = "user://progress.json"
const RANK_ORDER: Dictionary = {"": 0, "C": 1, "B": 2, "A": 3, "S": 4}

var current_level_index: int = 0
var unlocked: int = 1                 # сколько уровней открыто
var best: Dictionary = {}             # "1" -> {"rank": "A", "turns": 40, "score": 3000}
var sfx_muted: bool = false
var achievements: Dictionary = {}     # id -> true
var level_titles: Array[String] = []
var resume_requested: bool = false
var profile_warning: String = ""
var needs_profile_reset: bool = false
var audio_levels: Dictionary = {"Master": 100, "SFX": 100, "Ambience": 100, "AlarmSiren": 100}
var fullscreen: bool = false
var rebinds: Dictionary = {}
# Идентификатор действия -> физическая клавиша, на которую сводится ввод.
const REBINDABLE: Dictionary = {
	"up": KEY_W, "left": KEY_A, "down": KEY_S, "right": KEY_D, "wait": KEY_Z,
	"interact": KEY_E, "shock": KEY_F, "smoke": KEY_1, "decoy": KEY_2,
	"emp": KEY_3, "cloak": KEY_4, "undo": KEY_BACKSPACE,
}
const RESERVED_KEYS: Array[int] = [
	KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER,
	KEY_R, KEY_H, KEY_M, KEY_T, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_TAB, KEY_NONE,
]


func _ready() -> void:
	_load_titles()
	load_progress()
	if fullscreen and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _load_titles() -> void:
	level_titles.clear()
	for p in LEVEL_FILES:
		var f: FileAccess = FileAccess.open(p, FileAccess.READ)
		var title: String = p.get_file()
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				title = String(parsed.get("title", title))
		level_titles.append(title)


func load_progress() -> void:
	var parsed: Variant = LocalSave.read_json(SAVE_PATH)
	if not valid_progress(parsed):
		if not FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(SAVE_PATH + ".bak"):
			return
		parsed = LocalSave.read_json(SAVE_PATH + ".bak")
		if not valid_progress(parsed):
			needs_profile_reset = true
			profile_warning = "Профиль повреждён. Можно создать новый или продолжить без записи прогресса."
			return
		profile_warning = "Основной профиль недоступен. Загружена резервная копия."
	unlocked = int(parsed.get("unlocked", 1))
	best = parsed.get("best", {})
	sfx_muted = parsed.get("muted", false)
	achievements = parsed.get("ach", {})
	for channel: String in audio_levels:
		var levels: Dictionary = parsed.get("audio", {})
		audio_levels[channel] = int(levels.get(channel, 100))
	fullscreen = parsed.get("fullscreen", false)
	rebinds = parsed.get("rebinds", {})


func valid_progress(value: Variant) -> bool:
	if not (value is Dictionary) or not LevelSchema.integer(value.get("unlocked"), 1, LEVEL_FILES.size()):
		return false
	if not (value.get("best", {}) is Dictionary) or not (value.get("ach", {}) is Dictionary) \
			or not (value.get("muted", false) is bool) or not (value.get("audio", {}) is Dictionary) \
			or not (value.get("fullscreen", false) is bool) or not (value.get("rebinds", {}) is Dictionary):
		return false
	for key: String in value.get("best", {}):
		var record: Variant = value["best"][key]
		if not key.is_valid_int() or int(key) < 1 or int(key) > LEVEL_FILES.size() or not (record is Dictionary):
			return false
		if not RANK_ORDER.has(record.get("rank")) or record.get("rank") == "" \
				or not LevelSchema.integer(record.get("turns"), 0, 1000000) \
				or not LevelSchema.integer(record.get("score"), 0, 2147483647):
			return false
	for key: String in value.get("ach", {}):
		if not (value["ach"][key] is bool):
			return false
	for key: String in value.get("audio", {}):
		if not LevelSchema.integer(value["audio"][key], 0, 100):
			return false
	for id: String in value.get("rebinds", {}):
		var raw: Variant = value["rebinds"][id]
		if not LevelSchema.integer(raw, 1, 0x7fffffff) or not can_bind(id, int(raw), value["rebinds"]):
			return false
	return true


func confirm_new_profile() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		if DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".corrupt") != OK:
			push_warning("Не удалось сохранить копию повреждённого профиля")
			return false
	unlocked = 1
	best = {}
	achievements = {}
	rebinds = {}
	audio_levels = {"Master": 100, "SFX": 100, "Ambience": 100, "AlarmSiren": 100}
	needs_profile_reset = false
	profile_warning = ""
	save_progress()
	return true


func save_progress() -> void:
	if needs_profile_reset:
		return
	var previous: Variant = LocalSave.read_json(SAVE_PATH)
	if valid_progress(previous) and LocalSave.replace_json(SAVE_PATH + ".bak", previous) != OK:
		push_warning("Не удалось обновить резервную копию профиля")
		return
	if LocalSave.replace_json(SAVE_PATH, {
		"unlocked": unlocked, "best": best, "muted": sfx_muted, "ach": achievements, "audio": audio_levels,
		"fullscreen": fullscreen, "rebinds": rebinds,
	}) != OK:
		push_warning("Не удалось сохранить игровой профиль")


func can_bind(id: String, key: int, bindings: Dictionary) -> bool:
	if not REBINDABLE.has(id) or key in RESERVED_KEYS:
		return false
	for other: String in REBINDABLE:
		if other != id and (int(REBINDABLE[other]) == key or int(bindings.get(other, REBINDABLE[other])) == key):
			return false
	return true


func set_binding(id: String, key: int) -> bool:
	if not can_bind(id, key, rebinds):
		return false
	if key == int(REBINDABLE[id]):
		rebinds.erase(id)
	else:
		rebinds[id] = key
	save_progress()
	return true


func gameplay_key(physical_key: int) -> int:
	for id: String in rebinds:
		if int(rebinds[id]) == physical_key:
			return int(REBINDABLE[id])
		if int(REBINDABLE[id]) == physical_key:
			return KEY_NONE
	return physical_key


func record_result(level_index: int, rank: String, turns: int, score: int) -> void:
	var key: String = str(level_index + 1)
	var prev: Dictionary = best.get(key, {})
	var prev_rank: String = String(prev.get("rank", ""))
	if int(RANK_ORDER.get(rank, 0)) > int(RANK_ORDER.get(prev_rank, 0)) \
			or (rank == prev_rank and turns < int(prev.get("turns", 9999))):
		best[key] = {"rank": rank, "turns": turns, "score": score}
	if level_index + 2 > unlocked:
		unlocked = mini(level_index + 2, LEVEL_FILES.size())
	save_progress()


func best_rank(level_index: int) -> String:
	return String((best.get(str(level_index + 1), {}) as Dictionary).get("rank", ""))


func has_next_level() -> bool:
	return current_level_index + 1 < LEVEL_FILES.size()


# Возвращает true, если достижение получено впервые.
func unlock(id: String) -> bool:
	if achievements.has(id):
		return false
	achievements[id] = true
	save_progress()
	return true


func check_victory_achievements(sim: TurnManager, level_index: int) -> Array[String]:
	var got: Array[String] = []
	var par: int = int(sim.level_data.get("par_turns", 0))
	var checks: Dictionary = {
		"ghost": sim.alarm.times_triggered == 0,
		"collector": sim.chips_total > 0 and sim.player.chips >= sim.chips_total,
		"speed": sim.turn_number <= par,
		"untouched": sim.hp_lost == 0,
		"minimal": int(sim.stats["gadgets"]) == 0,
		"thief": int(sim.stats["pick"]) >= 2,
		"perfect": sim.get_rating() == "S",
		"survivor": sim.alarm.times_triggered > 0,
		"showman": int(sim.stats["maxmult"]) >= 4,
	}
	for id in checks:
		if checks[id] and unlock(id):
			got.append(id)
	var all_done: bool = true
	for i in range(LEVEL_FILES.size()):
		if i != level_index and best_rank(i) == "":
			all_done = false
	if all_done and unlock("legend"):
		got.append("legend")
	return got
