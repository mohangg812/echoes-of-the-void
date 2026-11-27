# res://ui/UITheme.gd
# Единый неоновый стиль интерфейса: цвета, шрифт, кнопки, панели. Всё строится кодом.
class_name UITheme
extends RefCounted

const BG: Color = Color("#07090E")
const PANEL: Color = Color(0.03, 0.055, 0.1, 0.92)
const CYAN: Color = Color("#00F0FF")
const AMBER: Color = Color("#FFB800")
const RED: Color = Color("#FF1E42")
const GOLD: Color = Color("#FFD700")
const GREEN: Color = Color("#2BFF8A")
const TEXT: Color = Color("#D8F6FF")
const DIM: Color = Color("#A2BED1")

static var _font: SystemFont = null
static var _font_bold: SystemFont = null


static func font(bold: bool = false) -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font_bold = SystemFont.new()
		_font_bold.font_names = _font.font_names
		_font_bold.font_weight = 700
		_font_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _font_bold if bold else _font


static func box(border: Color = CYAN, bg: Color = PANEL, border_w: int = 2, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size: int = 20, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func style_button(b: Button, size: int = 22, accent: Color = CYAN) -> void:
	b.add_theme_font_override("font", font(true))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.42, 0.5))
	b.add_theme_stylebox_override("normal", box(accent.darkened(0.45), Color(0.02, 0.05, 0.09, 0.95), 2))
	b.add_theme_stylebox_override("hover", box(accent, Color(0.04, 0.1, 0.16, 0.98), 2))
	b.add_theme_stylebox_override("pressed", box(Color.WHITE, Color(0.06, 0.16, 0.24, 1.0), 2))
	b.add_theme_stylebox_override("focus", box(AMBER, Color(0.04, 0.1, 0.16, 0.98), 3))
	b.add_theme_stylebox_override("disabled", box(Color(0.15, 0.2, 0.28), Color(0.02, 0.03, 0.05, 0.9), 2))
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 52)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func tex(path: String) -> Texture2D:
	return load("res://assets/%s.png" % path) as Texture2D
