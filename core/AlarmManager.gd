# res://core/AlarmManager.gd
# Глобальная фаза уровня: STEALTH -> SUSPICION -> ALARM_ACTIVE (6 ходов в тени до сброса).
class_name AlarmManager
extends RefCounted

enum State { STEALTH, SUSPICION, ALARM_ACTIVE }

const COOLDOWN_TURNS: int = 6

var state: int = State.STEALTH
var cooldown: int = 0
var last_known_player_pos: Vector2i = Vector2i(-1, -1)
var times_triggered: int = 0


func is_alarm() -> bool:
	return state == State.ALARM_ACTIVE


# Возвращает true, если тревога только что началась.
func trigger(pos: Vector2i) -> bool:
	last_known_player_pos = pos
	cooldown = COOLDOWN_TURNS
	if state == State.ALARM_ACTIVE:
		return false
	state = State.ALARM_ACTIVE
	times_triggered += 1
	return true


func refresh(pos: Vector2i) -> void:
	if state == State.ALARM_ACTIVE:
		last_known_player_pos = pos
		cooldown = COOLDOWN_TURNS


# Игрок остался в тени. Возвращает true, если тревога только что закончилась.
func step_turn_cooldown(player_seen: bool, player_pos: Vector2i) -> bool:
	if state != State.ALARM_ACTIVE:
		return false
	if player_seen:
		refresh(player_pos)
		return false
	cooldown -= 1
	if cooldown <= 0:
		cooldown = 0
		state = State.STEALTH
		return true
	return false


func get_state() -> Dictionary:
	return {"s": state, "c": cooldown, "l": last_known_player_pos, "t": times_triggered}


func set_state(d: Dictionary) -> void:
	state = d["s"]
	cooldown = d["c"]
	last_known_player_pos = d["l"]
	times_triggered = d["t"]
