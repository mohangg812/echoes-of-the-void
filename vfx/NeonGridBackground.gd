# res://vfx/NeonGridBackground.gd
# Обсидиановый фон с тонкой координатной сеткой по всему полю + неоновая рамка станции.
class_name NeonGridBackground
extends Node2D

var map_w: int = 20
var map_h: int = 12
var pulse: float = 0.0     # 0..1: подсветка сетки при тревоге
var alarm: bool = false
var _t: float = 0.0
const MARGIN: int = 14


func configure(w: int, h: int) -> void:
	map_w = w
	map_h = h
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if alarm:
		pulse = 0.5 + 0.5 * sin(_t * 6.0)
	queue_redraw()


func _draw() -> void:
	var ts: int = GridManager.TILE_SIZE
	var x0: int = -MARGIN * ts
	var y0: int = -MARGIN * ts
	var x1: int = (map_w + MARGIN) * ts
	var y1: int = (map_h + MARGIN) * ts
	draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), Color("#07090E"))
	var line: Color = Color("#131B2E")
	if alarm:
		line = line.lerp(Color(0.5, 0.05, 0.12), 0.35 + 0.4 * pulse)
	for gx in range(-MARGIN, map_w + MARGIN + 1):
		draw_line(Vector2(gx * ts, y0), Vector2(gx * ts, y1), line, 1.0)
	for gy in range(-MARGIN, map_h + MARGIN + 1):
		draw_line(Vector2(x0, gy * ts), Vector2(x1, gy * ts), line, 1.0)
	# цифровой дождь за пределами корпуса
	var gf: Font = UITheme.font()
	var glyphs: String = "01ABCDEF<>/#%"
	var cols: int = (map_w + MARGIN * 2) * 2
	for ci in range(cols):
		var cx: float = x0 + float(ci) * ts * 0.5 + 8.0
		var speed: float = 60.0 + float((ci * 37) % 90)
		var head: float = fmod(_t * speed + float((ci * 911) % 2000), float(y1 - y0 + 400)) + y0 - 200.0
		for k in range(9):
			var gy: float = head - float(k) * 17.0
			if gy < y0 or gy > y1:
				continue
			var ch: String = glyphs[(ci * 7 + k * 3 + int(_t * (4.0 + float(ci % 5)))) % glyphs.length()]
			var a: float = 0.22 * (1.0 - float(k) / 9.0)
			var col: Color = Color(0.2, 1.0, 0.9, a) if not alarm else Color(1.0, 0.2, 0.3, a)
			if k == 0:
				col = Color(0.8, 1.6, 1.5, 0.45)
			draw_string(gf, Vector2(cx, gy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	# рамка корпуса станции
	var rim: Color = Color(0.0, 0.55, 0.65, 0.5) if not alarm else Color(1.0, 0.1, 0.2, 0.4 + 0.3 * pulse)
	draw_rect(Rect2(-6, -6, map_w * ts + 12, map_h * ts + 12), rim, false, 2.0)
	# координатные метки по верху и левому краю
	var f: Font = UITheme.font()
	for gx in range(0, map_w, 2):
		draw_string(f, Vector2(gx * ts + 4, -12), "%02d" % gx, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.35, 0.45, 0.8))
	for gy in range(0, map_h, 2):
		draw_string(f, Vector2(-30, gy * ts + 28), "%02d" % gy, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.35, 0.45, 0.8))
