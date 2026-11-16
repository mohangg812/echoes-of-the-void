# res://core/TacticalHistory.gd
# Стек снимков состояния для отката хода (Backspace).
class_name TacticalHistory
extends RefCounted

const MAX_DEPTH: int = 300

var stack: Array[Dictionary] = []


func push(snapshot: Dictionary) -> void:
	stack.append(snapshot)
	if stack.size() > MAX_DEPTH:
		stack.pop_front()


func pop() -> Dictionary:
	if stack.is_empty():
		return {}
	return stack.pop_back()


func size() -> int:
	return stack.size()


func clear() -> void:
	stack.clear()
