# res://vfx/FxManager.gd
# Библиотека эффектов: взрывы частиц, послеобразы, кольца ударных волн, трассеры, всплывающий текст.
# Всё аддитивное и HDR-яркое — Glow из WorldEnvironment превращает это в неон.
class_name FxManager
extends Node2D

var _glow: Texture2D
var _add_mat: CanvasItemMaterial


func _init() -> void:
	z_index = 30
	_glow = UITheme.tex("security/light_radial_glow")
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


class Ring extends Node2D:
	var radius: float = 0.0
	var max_r: float = 96.0
	var color: Color = Color(0.2, 1.4, 1.6)
	var life: float = 0.0
	var dur: float = 0.7
	var width: float = 3.0
	var fill: bool = false

	func _process(d: float) -> void:
		life += d
		var k: float = clampf(life / dur, 0.0, 1.0)
		radius = max_r * (1.0 - pow(1.0 - k, 3.0))
		modulate.a = 1.0 - k
		queue_redraw()
		if life >= dur:
			queue_free()

	func _draw() -> void:
		if fill:
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.045))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, width)
		draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.45), width * 0.5)


class Tracer extends Node2D:
	var a: Vector2
	var b: Vector2
	var color: Color = Color(2.4, 0.3, 0.4)
	var life: float = 0.0
	var dur: float = 0.35

	func _process(d: float) -> void:
		life += d
		modulate.a = 1.0 - life / dur
		queue_redraw()
		if life >= dur:
			queue_free()

	func _draw() -> void:
		draw_line(a, b, color, 8.0)
		draw_line(a, b, Color(2.5, 2.5, 2.5), 2.5)


class Bolt extends Node2D:
	# электрическая дуга между двумя точками
	var a: Vector2
	var b: Vector2
	var color: Color = Color(0.5, 1.8, 2.4)
	var life: float = 0.0
	var pts: PackedVector2Array = PackedVector2Array()

	func _ready() -> void:
		_regen()

	func _regen() -> void:
		pts.clear()
		var n: int = 9
		var dir: Vector2 = (b - a)
		var perp: Vector2 = dir.normalized().orthogonal()
		for i in range(n + 1):
			var t: float = float(i) / float(n)
			var jitter: float = 0.0 if (i == 0 or i == n) else sin(float(i) * 12.9898 + life * 90.0) * 9.0
			pts.append(a + dir * t + perp * jitter)

	func _process(d: float) -> void:
		life += d
		_regen()
		modulate.a = 1.0 - life / 0.4
		queue_redraw()
		if life >= 0.4:
			queue_free()

	func _draw() -> void:
		draw_polyline(pts, color, 5.0)
		draw_polyline(pts, Color(2.5, 2.5, 2.5), 1.8)


func ring(pos: Vector2, radius: float, color: Color, dur: float = 0.7, width: float = 3.0, fill: bool = false) -> void:
	var r := Ring.new()
	r.position = pos
	r.max_r = radius
	r.color = color
	r.dur = dur
	r.width = width
	r.fill = fill
	add_child(r)


func tracer(a: Vector2, b: Vector2, color: Color = Color(2.4, 0.3, 0.4)) -> void:
	var t := Tracer.new()
	t.a = a
	t.b = b
	t.color = color
	add_child(t)


func bolt(a: Vector2, b: Vector2, color: Color = Color(0.5, 1.8, 2.4)) -> void:
	var t := Bolt.new()
	t.a = a
	t.b = b
	t.color = color
	add_child(t)


# Взрыв светящихся частиц.
func burst(pos: Vector2, color: Color, amount: int = 24, speed: float = 180.0, life: float = 0.6,
		size: float = 0.12, spread: float = 180.0, dir: Vector2 = Vector2.RIGHT, damping: float = 0.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = _glow
	p.material = _add_mat
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.96
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = damping
	p.damping_max = damping * 1.5
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# Облачко дыма (медленное, серо-голубое, обычное смешивание).
func puff(pos: Vector2, amount: int = 14) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = _glow
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.4
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2(0, -8)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 45.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = Color(0.7, 0.85, 1.0, 0.4)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.7))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# Послеобраз спрайта (шлейф рывка, погони).
func ghost(tex: Texture2D, pos: Vector2, rot: float, scale_v: Vector2, color: Color, dur: float = 0.4) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.rotation = rot
	s.scale = scale_v
	s.modulate = color
	s.material = _add_mat
	add_child(s)
	var tw: Tween = create_tween()
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.parallel().tween_property(s, "scale", scale_v * 1.15, dur)
	tw.tween_callback(s.queue_free)


func float_text(pos: Vector2, text: String, color: Color, size: int = 22, rise: float = 40.0) -> void:
	var l: Label = UITheme.label(text, size, color, true)
	l.position = pos + Vector2(-60, -52)
	l.size = Vector2(120, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 40
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.3, 0.3)
	add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "scale", Vector2(1.25, 1.25), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(l, "position:y", l.position.y - rise, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_callback(l.queue_free)


# Вспышка света на месте (аддитивный круг).
func flash_at(pos: Vector2, color: Color, radius_px: float = 120.0, dur: float = 0.35) -> void:
	var s := Sprite2D.new()
	s.texture = _glow
	s.position = pos
	s.material = _add_mat
	s.modulate = color
	var sc: float = radius_px / 24.0
	s.scale = Vector2(sc * 0.3, sc * 0.3)
	add_child(s)
	var tw: Tween = create_tween()
	tw.tween_property(s, "scale", Vector2(sc, sc), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, dur)
	tw.tween_callback(s.queue_free)
