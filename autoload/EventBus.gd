# res://autoload/EventBus.gd
# События игрового сеанса. Чистая симуляция не зависит от автозагрузок.
extends Node

signal turn_completed(turn: int)
signal alarm_state_changed(new_state: int)
signal mission_failed(reason: String)
signal mission_accomplished(stats: Dictionary)
signal hud_refresh(sim: TurnManager, danger: int)
