# res://entities/interactables/LootItem.gd
# Главное золото (Ядро Данных), чипы, ключ-карты на полу, аптечки.
class_name LootItem
extends GridEntity

var kind: String = "chip"     # "gold" | "chip" | "keycard" | "medkit"
var value: int = 500
var item_name: String = ""
var color: String = ""        # для keycard
var collected: bool = false


func get_state() -> Dictionary:
	return {"c": collected}


func set_state(d: Dictionary) -> void:
	collected = d["c"]
