# res://ui/EventFeed.gd
# Лента событий справа: короткие строки, которые появляются со сдвигом и гаснут.
class_name EventFeed
extends VBoxContainer

const MAX_LINES: int = 9


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_END


func push(text: String, color: Color = UITheme.TEXT, turn: int = -1) -> void:
	var l: Label = UITheme.label(("[%03d] " % turn if turn >= 0 else "") + text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(size.x, 0)
	l.modulate.a = 0.0
	add_child(l)
	while get_child_count() > MAX_LINES:
		var old: Node = get_child(0)
		remove_child(old)
		old.queue_free()
	var tw: Tween = create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.18)
	tw.tween_interval(9.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)


func clear_all() -> void:
	for c in get_children():
		c.queue_free()
