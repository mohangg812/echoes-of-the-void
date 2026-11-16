# res://autoload/EventBus.gd
# Глобальная шина сигналов: интерфейс и сцены общаются через неё, а не напрямую.
extends Node

signal turn_started(turn: int)
signal turn_completed(turn: int)
signal alarm_state_changed(new_state: int)
signal mission_failed(reason: String)
signal mission_accomplished(stats: Dictionary)
signal toast(text: String, color: Color)
signal hud_refresh()
