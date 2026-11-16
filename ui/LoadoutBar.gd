# res://ui/LoadoutBar.gd
# Нижняя панель: карточки гаджетов, ключ-карты, щит, рывок, шокер — всё рисуется кодом.
class_name LoadoutBar
extends Control

const NAMES: Array[String] = ["ДЫМ", "МАНОК", "ЭМИ", "ПЛАЩ"]
const ICONS: Array[String] = ["gadgets/gadget_flashbang", "gadgets/gadget_noise_decoy", "gadgets/vfx_emp_pulse", "gadgets/gadget_hologram_decoy"]
const KEYS: Array[String] = ["smoke", "decoy", "emp", "cloak"]
const CARDS: Array = [["RED", Color("#FF1E42")], ["BLUE", Color("#2D7CFF")], ["YELLOW", Color("#FFD700")]]

var sim: TurnManager
var flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _icons: Array[Texture2D] = []
var _t: float = 0.0
var _hp_anim: float = 2.0
var shield_hit: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in ICONS:
		_icons.append(UITheme.tex(p))


func setup(s: TurnManager) -> void:
	sim = s
	_hp_anim = float(s.player.hp)


func kick(slot: int) -> void:
	if slot >= 1 and slot <= 4:
		flash[slot - 1] = 1.0


func _process(delta: float) -> void:
	_t += delta
	for i in range(4):
		flash[i] = maxf(0.0, flash[i] - delta * 3.0)
	shield_hit = maxf(0.0, shield_hit - delta * 2.0)
	if sim != null:
		_hp_anim = lerpf(_hp_anim, float(sim.player.hp), minf(1.0, delta * 8.0))
	queue_redraw()


func _cut_poly(r: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(c, 0), r.position + Vector2(r.size.x, 0), r.position + Vector2(r.size.x, r.size.y - c),
		r.position + Vector2(r.size.x - c, r.size.y), r.position + Vector2(0, r.size.y), r.position + Vector2(0, c)])


func _draw() -> void:
	if sim == null:
		return
	var f: Font = UITheme.font(true)
	var p: PlayerController = sim.player
	# карточки гаджетов
	for i in range(4):
		var r := Rect2(16 + i * 130, 12, 120, 74)
		var n: int = int(p.gadgets[KEYS[i]])
		var live: bool = n > 0
		var accent: Color = Color("#00F0FF") if live else Color(0.3, 0.35, 0.42)
		if i == 3 and p.cloak_turns > 0:
			accent = Color("#9D7BFF")
		var poly: PackedVector2Array = _cut_poly(r, 10.0)
		draw_colored_polygon(poly, Color(0.015, 0.04, 0.07, 0.95))
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color(accent.r, accent.g, accent.b, 0.8), 2.0)
		if flash[i] > 0.0:
			draw_colored_polygon(poly, Color(0.4, 1.2, 1.4, 0.5 * flash[i]))
			draw_polyline(closed, Color(2.0, 2.0, 2.0, flash[i]), 4.0)
		draw_texture_rect(_icons[i], Rect2(r.position + Vector2(8, 14), Vector2(48, 48)), false, Color.WHITE if live else Color(0.35, 0.35, 0.4, 0.55))
		# хоткей
		draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(18, 18)), Color(accent.r, accent.g, accent.b, 0.9))
		draw_string(f, r.position + Vector2(8, 18), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0.05, 0.08))
		draw_string(f, r.position + Vector2(62, 30), NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(accent.r, accent.g, accent.b, 0.95))
		draw_string(f, r.position + Vector2(62, 62), "x%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE if live else Color(0.4, 0.45, 0.5))
	# ключ-карты
	var kx: float = 560.0
	draw_string(f, Vector2(kx, 22), "КЛЮЧ-КАРТЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.62, 0.72))
	for i in range(3):
		var col: Color = CARDS[i][1]
		var has: bool = p.keycards.has(CARDS[i][0])
		var cr := Rect2(kx + i * 44, 30, 36, 52)
		if has:
			var bob: float = sin(_t * 3.0 + i) * 1.5
			cr.position.y += bob
			draw_rect(cr, Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 0.95))
			draw_rect(Rect2(cr.position + Vector2(5, 6), Vector2(26, 10)), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(cr.position + Vector2(5, 22), Vector2(14, 4)), Color(1, 1, 1, 0.7))
			draw_rect(Rect2(cr.position + Vector2(5, 30), Vector2(20, 4)), Color(1, 1, 1, 0.45))
		else:
			draw_rect(cr, Color(col.r, col.g, col.b, 0.07))
			draw_rect(cr, Color(col.r, col.g, col.b, 0.3), false, 1.5)
	# щит
	var sx: float = 720.0
	draw_string(f, Vector2(sx, 22), "ЩИТ / ТЕЛО", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.62, 0.72))
	for i in range(PlayerController.MAX_HP):
		var c := Vector2(sx + 24 + i * 56, 56)
		var filled: float = clampf(_hp_anim - float(i), 0.0, 1.0)
		var hex := PackedVector2Array()
		for k in range(6):
			var a: float = TAU * float(k) / 6.0 + PI / 6.0
			hex.append(c + Vector2(cos(a), sin(a)) * 22.0)
		draw_colored_polygon(hex, Color(0.12, 0.02, 0.04, 0.9))
		if filled > 0.0:
			var hex2 := PackedVector2Array()
			for k in range(6):
				var a2: float = TAU * float(k) / 6.0 + PI / 6.0
				hex2.append(c + Vector2(cos(a2), sin(a2)) * 22.0 * filled)
			var pulse: float = 1.0 + 0.25 * sin(_t * 5.0 + i)
			draw_colored_polygon(hex2, Color(0.2 * pulse, 1.1 * pulse, 1.3 * pulse, 0.95))
		var hc: PackedVector2Array = hex.duplicate()
		hc.append(hex[0])
		draw_polyline(hc, Color(0.2, 1.0, 1.2, 0.8) if filled > 0.0 else Color(0.6, 0.15, 0.2, 0.9), 2.0)
	# рывок
	var dx: float = 860.0
	draw_string(f, Vector2(dx, 22), "РЫВОК", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.62, 0.72))
	var dc := Vector2(dx + 26, 58)
	var ready: bool = p.dash_cd <= 0
	var prog: float = 1.0 - float(p.dash_cd) / float(PlayerController.DASH_COOLDOWN)
	draw_arc(dc, 20.0, 0.0, TAU, 32, Color(0.2, 0.3, 0.4, 0.8), 3.0)
	draw_arc(dc, 20.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, Color(2.0, 1.4, 0.2) if ready else Color(0.2, 0.8, 1.0), 4.0)
	draw_string(f, dc + Vector2(-5, 6), "»" if ready else str(p.dash_cd), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(f, Vector2(dx + 54, 54), "Shift+", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.7, 0.8))
	draw_string(f, Vector2(dx + 54, 68), "шаг", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.7, 0.8))
	# шокер
	var shx: float = 990.0
	draw_string(f, Vector2(shx, 22), "ШОКЕР  F", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.62, 0.72))
	var charges: int = int(p.gadgets["shock"])
	for i in range(3):
		var pr := Rect2(shx + i * 22, 36, 16, 36)
		if i < charges:
			draw_rect(pr, Color(0.6, 1.6, 2.0, 0.95))
			draw_rect(Rect2(pr.position + Vector2(4, 4), Vector2(8, 28)), Color(0.9, 1.9, 2.2, 0.8))
		else:
			draw_rect(pr, Color(0.5, 0.6, 0.7, 0.15))
			draw_rect(pr, Color(0.5, 0.6, 0.7, 0.4), false, 1.0)
	draw_string(f, Vector2(1090, 60), "H — справка", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.68, 0.8))
	if p.cloak_turns > 0:
		draw_string(f, Vector2(1090, 36), "ПЛАЩ: %d" % p.cloak_turns, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9D7BFF"))
	if shield_hit > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.1, 0.2, 0.25 * shield_hit))
