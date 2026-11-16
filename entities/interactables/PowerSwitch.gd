# res://entities/interactables/PowerSwitch.gd
# Рубильник / терминал: пока включён (on), отключает всё с таким же group_id
# (лазеры, камеры, турели) и открывает двери этой группы.
class_name PowerSwitch
extends GridEntity

var target_group_id: String = ""
var description: String = ""
var kind: String = "switch"   # "switch" или "terminal" (только внешний вид)
var on: bool = false


func get_state() -> Dictionary:
	return {"o": on}


func set_state(d: Dictionary) -> void:
	on = d["o"]
