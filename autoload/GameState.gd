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


func _ready() -> void:
	_load_titles()
	load_progress()


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
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	unlocked = clampi(int(parsed.get("unlocked", 1)), 1, LEVEL_FILES.size())
	best = parsed.get("best", {})
	sfx_muted = bool(parsed.get("muted", false))
	achievements = parsed.get("ach", {})


func save_progress() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"unlocked": unlocked, "best": best, "muted": sfx_muted, "ach": achievements}))


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
