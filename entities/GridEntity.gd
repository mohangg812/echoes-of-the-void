# res://entities/GridEntity.gd
# База любой сущности на сетке: логическая клетка + направление. Пиксели — только во вьюхе.
class_name GridEntity
extends RefCounted

var id: String = ""
var grid_pos: Vector2i = Vector2i.ZERO
var start_grid_pos: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i(1, 0)


func get_state() -> Dictionary:
	return {"p": grid_pos, "f": facing}


func set_state(d: Dictionary) -> void:
	grid_pos = d["p"]
	facing = d["f"]


func face_towards(target: Vector2i) -> void:
	var delta: Vector2i = target - grid_pos
	if delta == Vector2i.ZERO:
		return
	if absi(delta.x) >= absi(delta.y):
		facing = Vector2i(signi(delta.x), 0)
	else:
		facing = Vector2i(0, signi(delta.y))
