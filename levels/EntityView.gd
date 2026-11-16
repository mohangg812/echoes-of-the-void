# res://levels/EntityView.gd
# Визуальная оболочка одной сущности: спрайт, свечение, значок состояния, плавное перемещение.
# Логическая позиция живёт в симуляции; здесь только интерполяция в пиксели.
class_name EntityView
extends Node2D

var spr: Sprite2D
var glow: Sprite2D
var badge: Label
var cell: Vector2i = Vector2i(-999, -999)
var key_color: Color = Color(0, 0, 0, 0)
var _move_tween: Tween
var _rot_tween: Tween
var spin: float = 0.0
var pulse: float = 0.0
var bob: float = 0.0
var _t: float = 0.0
var _base_mod: Color = Color.WHITE


func _init() -> void:
	glow = Sprite2D.new()
	glow.texture = UITheme.tex("security/light_radial_glow")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.visible = false
	add_child(glow)
	spr = Sprite2D.new()
	add_child(spr)
	badge = UITheme.label("", 24, UITheme.AMBER, true)
	badge.position = Vector2(-14, -46)
	badge.size = Vector2(40, 28)
	badge.z_index = 20
	badge.visible = false
	add_child(badge)


func setup(texture_name: String, z: int = 0) -> void:
	spr.texture = UITheme.tex(texture_name)
	z_index = z


func set_tex(texture_name: String) -> void:
	var t: Texture2D = UITheme.tex(texture_name)
	if spr.texture != t:
		spr.texture = t


func set_glow(color: Color, scale_mul: float = 2.0) -> void:
	glow.visible = color.a > 0.0
	glow.modulate = color
	glow.scale = Vector2(scale_mul, scale_mul)


func set_tint(c: Color) -> void:
	_base_mod = c
	spr.modulate = c


func place(c: Vector2i, animate: bool, dur: float = 0.12) -> void:
	var target: Vector2 = Vector2(c.x * GridManager.TILE_SIZE + 24, c.y * GridManager.TILE_SIZE + 24)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if animate and cell.x > -900 and c != cell:
		_move_tween = create_tween()
		_move_tween.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		position = target
	cell = c


func face(dir: Vector2i, animate: bool = true, offset: float = 0.0) -> void:
	if dir == Vector2i.ZERO:
		return
	var target: float = Vector2(dir).angle() + offset
	var diff: float = angle_difference(spr.rotation, target)
	if _rot_tween != null and _rot_tween.is_valid():
		_rot_tween.kill()
	if animate and absf(diff) > 0.01:
		_rot_tween = create_tween()
		_rot_tween.tween_property(spr, "rotation", spr.rotation + diff, 0.09)
	else:
		spr.rotation = target


func set_badge(text: String, color: Color) -> void:
	var changed: bool = badge.text != text
	badge.visible = text != ""
	badge.text = text
	badge.add_theme_color_override("font_color", color)
	if changed and text != "":
		badge.pivot_offset = Vector2(14, 14)
		badge.scale = Vector2(0.2, 0.2)
		var tw: Tween = create_tween()
		tw.tween_property(badge, "scale", Vector2(1.7, 1.7), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(badge, "scale", Vector2.ONE, 0.1)


func _process(delta: float) -> void:
	_t += delta
	if spin != 0.0:
		spr.rotation += spin * delta
	if bob != 0.0:
		spr.position.y = sin(_t * 4.0 + float(cell.x + cell.y)) * bob
	if pulse != 0.0:
		var s: float = 1.0 + sin(_t * 3.0) * pulse
		spr.scale = Vector2(s, s)
		if glow.visible:
			glow.modulate.a = 0.55 + sin(_t * 3.0) * 0.25


func _draw() -> void:
	if key_color.a > 0.0:
		draw_rect(Rect2(10, -22, 10, 14), Color(0, 0, 0, 0.9))
		draw_rect(Rect2(11, -21, 8, 12), key_color)
		draw_rect(Rect2(12, -19, 6, 2), Color(1, 1, 1, 0.8))


func refresh_draw() -> void:
	queue_redraw()
