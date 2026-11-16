# res://entities/interactables/ElectronicDoor.gd
# Дверь с электронным замком: открывается ключ-картой нужного цвета или выключением питания (group_id).
# Охрана проходит свободно.
class_name ElectronicDoor
extends GridEntity

var required_keycard: String = ""   # "RED" / "BLUE" / "YELLOW" / "" (только питание)
var group_id: String = ""
var key_open: bool = false
var group_open: bool = false


func is_open() -> bool:
	return key_open or group_open


func can_player_unlock(player_keycards: Array) -> bool:
	if is_open():
		return true
	return required_keycard != "" and player_keycards.has(required_keycard)


func get_state() -> Dictionary:
	return {"k": key_open, "g": group_open}


func set_state(d: Dictionary) -> void:
	key_open = d["k"]
	group_open = d["g"]
