# res://ui/NeonPanel.gd
# Панель со срезанными углами, неоновой кромкой, бегущим бликом и уголками-скобками.
class_name NeonPanel
extends Control

var accent: Color = Color("#00F0FF")
var fill: Color = Color(0.02, 0.04, 0.08, 0.84)
var cut: float = 14.0
var title: String = ""
var flash: float = 0.0          # 0..1 вспышка (при событии)
var animate: bool = true
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 6.0


func _process(delta: float) -> void:
	_t += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 2.5)
	queue_redraw()


func _outline() -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y
	var c: float = cut
	return PackedVector2Array([Vector2(c, 0), Vector2(w, 0), Vector2(w, h - c), Vector2(w - c, h), Vector2(0, h), Vector2(0, c)])


func _draw() -> void:
	var pts: PackedVector2Array = _outline()
	var w: float = size.x
	var h: float = size.y
	draw_colored_polygon(pts, fill)
	# вертикальный градиент: светлее сверху
	var strips: int = 6
	for i in range(strips):
		var a: float = 0.06 * (1.0 - float(i) / float(strips))
		draw_rect(Rect2(cut * 0.5, 2 + i * (h / float(strips * 2)), w - cut, h / float(strips * 2)), Color(accent.r, accent.g, accent.b, a))
	# сканирующая сетка
	var y: float = 6.0
	while y < h - 4.0:
		draw_line(Vector2(4, y), Vector2(w - 4, y), Color(accent.r, accent.g, accent.b, 0.035), 1.0)
		y += 4.0
	var edge: Color = accent
	edge.a = 0.55 + 0.35 * flash
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, edge, 2.0, true)
	if flash > 0.0:
		draw_polyline(closed, Color(accent.r * 2.0, accent.g * 2.0, accent.b * 2.0, flash), 4.0, true)
	# уголки
	var br: Color = Color(accent.r * 1.5, accent.g * 1.5, accent.b * 1.5, 0.95)
	draw_line(Vector2(cut, 0), Vector2(cut + 18, 0), br, 3.0)
	draw_line(Vector2(w, h - cut - 18), Vector2(w, h - cut), br, 3.0)
	draw_line(Vector2(0, h), Vector2(18, h), br, 3.0)
	# бегущий блик по верхней кромке
	if animate:
		var x: float = fmod(_t * 170.0, w + 160.0) - 80.0
		var x0: float = clampf(x, cut, w)
		var x1: float = clampf(x + 80.0, cut, w)
		if x1 > x0:
			draw_line(Vector2(x0, 0.5), Vector2(x1, 0.5), Color(accent.r * 2.0, accent.g * 2.0, accent.b * 2.0, 0.9), 2.0)
	if title != "":
		draw_string(UITheme.font(true), Vector2(cut + 4, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(accent.r, accent.g, accent.b, 0.8))
