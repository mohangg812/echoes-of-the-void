# res://autoload/SceneTransition.gd
# Плавные переходы между сценами: затемнение с неоновой полосой.
extends CanvasLayer

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0.03, 0.035, 0.055, 1.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw: Tween = create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, 0.22)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2: Tween = create_tween()
	tw2.tween_property(_rect, "modulate:a", 0.0, 0.28)
	await tw2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
