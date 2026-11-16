# res://vfx/AlarmLightingController.gd
# Освещение уровня: холодный циан в стелсе, пульсирующий багровый при тревоге.
# CanvasModulate красит только мир (HUD лежит в отдельных CanvasLayer), плюс виньетка и CRT-шейдер поверх.
class_name AlarmLightingController
extends Node

var modulate_node: CanvasModulate
var vignette: TextureRect
var crt: ColorRect
var flash_rect: ColorRect
var alarm: bool = false
var _t: float = 0.0
var _flash: float = 0.0
var _flash_color: Color = Color.RED
var _mat: ShaderMaterial
var _alarm_amt: float = 0.0
var _glitch: float = 0.0


func build(parent: Node) -> void:
	modulate_node = CanvasModulate.new()
	modulate_node.color = Color(0.92, 0.97, 1.0)
	parent.add_child(modulate_node)

	var vl := CanvasLayer.new()
	vl.layer = 5
	parent.add_child(vl)
	vignette = TextureRect.new()
	vignette.texture = UITheme.tex("overlays/vfx_overlay_alarm_vignette")
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate = Color(1, 1, 1, 0)
	vl.add_child(vignette)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0, 0, 0)
	vl.add_child(flash_rect)

	var cl := CanvasLayer.new()
	cl.layer = 60
	parent.add_child(cl)
	crt = ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = load("res://vfx/shaders/crt_cyberpunk.gdshader") as Shader
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	crt.material = _mat
	cl.add_child(crt)


func kick_glitch(amount: float = 1.0) -> void:
	_glitch = maxf(_glitch, amount)


func set_alarm(on: bool) -> void:
	alarm = on


func flash(color: Color, strength: float = 0.5) -> void:
	_flash_color = color
	_flash = strength


func _process(delta: float) -> void:
	_t += delta
	var target: Color = Color(0.92, 0.97, 1.0)
	var vig: float = 0.0
	if alarm:
		var k: float = 0.5 + 0.5 * sin(_t * 6.0)
		target = Color(1.0, 0.72 + 0.12 * (1.0 - k), 0.74 + 0.12 * (1.0 - k))
		vig = 0.45 + 0.4 * k
	modulate_node.color = modulate_node.color.lerp(target, minf(1.0, delta * 8.0))
	vignette.modulate.a = lerpf(vignette.modulate.a, vig, minf(1.0, delta * 8.0))
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.6)
		flash_rect.color = Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash)
	else:
		flash_rect.color.a = 0.0
	_alarm_amt = lerpf(_alarm_amt, 1.0 if alarm else 0.0, minf(1.0, delta * 6.0))
	if _mat != null:
		_glitch = maxf(0.0, _glitch - delta * 2.2)
		_mat.set_shader_parameter("alarm", _alarm_amt)
		_mat.set_shader_parameter("glitch", _glitch)
