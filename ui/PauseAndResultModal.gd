# res://ui/PauseAndResultModal.gd
# Модальные окна поверх игры: брифинг, пауза, победа (рейтинг S/A/B/C), поражение.
class_name PauseAndResultModal
extends CanvasLayer

signal action_chosen(action: String)

var _root: Control
var _dim: ColorRect
var _panel: PanelContainer
var _vbox: VBoxContainer
var _buttons: Array[Button] = []
var is_open: bool = false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.02, 0.04, 0.78)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(_panel)
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(_vbox)


func _clear() -> void:
	for c in _vbox.get_children():
		c.queue_free()
	_buttons.clear()


func _open(border: Color) -> void:
	_panel.add_theme_stylebox_override("panel", UITheme.box(border, Color(0.025, 0.045, 0.085, 0.97), 3, 2))
	_root.visible = true
	is_open = true
	if _buttons.size() > 0:
		_buttons[0].call_deferred("grab_focus")


func close() -> void:
	_root.visible = false
	is_open = false


func _add_button(text: String, action: String, accent: Color = UITheme.CYAN) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b, 22, accent)
	b.pressed.connect(func() -> void:
		ProceduralSFX.play("select")
		action_chosen.emit(action))
	_vbox.add_child(b)
	_buttons.append(b)
	return b


func _title(text: String, color: Color, size: int = 42) -> void:
	var l := UITheme.label(text, size, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(l)


func show_briefing(data: Dictionary, index: int) -> void:
	_clear()
	_title("ОПЕРАЦИЯ %02d" % (index + 1), UITheme.DIM, 20)
	var t := UITheme.label(String(data.get("title", "")).replace("ОПЕРАЦИЯ %02d: " % (index + 1), ""), 40, UITheme.CYAN, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(t)
	var sub := UITheme.label(String(data.get("subtitle", "")), 19, UITheme.AMBER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var pbox := Control.new()
	pbox.custom_minimum_size = Vector2(176, 176)
	var frame := NeonPanel.new()
	frame.size = Vector2(176, 176)
	frame.cut = 12.0
	pbox.add_child(frame)
	var portrait := TextureRect.new()
	portrait.texture = UITheme.tex("portraits/portrait_handler")
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(12, 12)
	portrait.size = Vector2(152, 152)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pbox.add_child(portrait)
	row.add_child(pbox)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_theme_constant_override("separation", 10)
	txt.add_child(UITheme.label("КУРАТОР НА СВЯЗИ:", 16, UITheme.DIM, true))
	var lines: Array[Label] = []
	for line in data.get("briefing", []):
		var l := UITheme.label("— " + String(line), 18, UITheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(620, 0)
		l.visible_ratio = 0.0
		txt.add_child(l)
		lines.append(l)
	row.add_child(txt)
	_vbox.add_child(row)
	_add_button("НАЧАТЬ МИССИЮ  [Enter]", "start")
	_add_button("В ГЛАВНОЕ МЕНЮ", "menu", UITheme.DIM)
	_open(UITheme.CYAN)
	var tw: Tween = create_tween()
	for l in lines:
		tw.tween_callback(func() -> void: ProceduralSFX.play("blip_h", -4.0))
		tw.tween_property(l, "visible_ratio", 1.0, maxf(0.4, float(l.text.length()) / 70.0))
		tw.tween_interval(0.1)


func show_pause() -> void:
	_clear()
	_title("ПАУЗА", UITheme.CYAN)
	_add_button("ПРОДОЛЖИТЬ  [Esc]", "resume")
	_add_button("ПЕРЕЗАПУСК УРОВНЯ  [R]", "restart", UITheme.AMBER)
	_add_button("БРИФИНГ", "briefing", UITheme.CYAN)
	_add_button("ЗВУК ВКЛ/ВЫКЛ  [M]", "mute", UITheme.DIM)
	_add_button("В ГЛАВНОЕ МЕНЮ", "menu", UITheme.RED)
	_open(UITheme.CYAN)


func show_victory(stats: Dictionary, has_next: bool) -> void:
	_clear()
	var rank: String = String(stats["rank"])
	var rank_color: Color = {"S": UITheme.GOLD, "A": UITheme.GREEN, "B": UITheme.CYAN, "C": UITheme.AMBER}[rank]
	_title("МИССИЯ ВЫПОЛНЕНА", UITheme.GREEN, 38)
	var rk_box := CenterContainer.new()
	rk_box.custom_minimum_size = Vector2(0, 130)
	var rk := UITheme.label(rank, 120, rank_color, true)
	rk.add_theme_constant_override("outline_size", 10)
	rk.pivot_offset = Vector2(40, 70)
	rk.scale = Vector2(6, 6)
	rk.modulate.a = 0.0
	rk_box.add_child(rk)
	_vbox.add_child(rk_box)
	# звёзды
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 10)
	var earned: int = {"S": 3, "A": 3, "B": 2, "C": 1}[rank]
	var star_tex: Texture2D = UITheme.tex("ui/ui_rating_stars")
	for i in range(3):
		var at := AtlasTexture.new()
		at.atlas = star_tex
		at.region = Rect2(i * 32, 0, 32, 32)
		var tr := TextureRect.new()
		tr.texture = at
		tr.custom_minimum_size = Vector2(52, 52)
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.modulate = Color(1.6, 1.4, 0.5) if i < earned else Color(0.2, 0.2, 0.25, 0.6)
		tr.pivot_offset = Vector2(26, 26)
		tr.scale = Vector2.ZERO
		stars.add_child(tr)
	_vbox.add_child(stars)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 50)
	grid.add_theme_constant_override("v_separation", 4)
	var values: Array = []
	var rows: Array = [
		["Ходов (пар %d)" % int(stats["par"]), int(stats["turns"])],
		["Тревог поднято", int(stats["alarms"])],
		["Чипов собрано (из %d)" % int(stats["chips_total"]), int(stats["chips"])],
		["Лучший множитель стиля", int(stats.get("maxmult", 1))],
		["Откатов хода", int(stats["undos"])],
		["Счёт", int(stats["score"])],
	]
	for r in rows:
		grid.add_child(UITheme.label(String(r[0]), 22, UITheme.DIM))
		var v := UITheme.label("0", 22, UITheme.TEXT, true)
		grid.add_child(v)
		values.append([v, int(r[1])])
	var gc := CenterContainer.new()
	gc.add_child(grid)
	_vbox.add_child(gc)
	var ach_ids: Array = stats.get("achievements", [])
	var ach_labels: Array[Label] = []
	for id in ach_ids:
		var info: Array = GameState.ACHIEVEMENTS[id]
		var al := UITheme.label("ДОСТИЖЕНИЕ: %s — %s" % [String(info[0]), String(info[1])], 18, UITheme.GOLD, true)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.modulate.a = 0.0
		_vbox.add_child(al)
		ach_labels.append(al)
	if has_next:
		_add_button("СЛЕДУЮЩАЯ МИССИЯ  [Enter]", "next", UITheme.GREEN)
	_add_button("ПЕРЕИГРАТЬ  [R]", "restart", UITheme.AMBER)
	_add_button("В ГЛАВНОЕ МЕНЮ", "menu", UITheme.DIM)
	_open(rank_color)
	# анимация: счётчики, звёзды, штамп ранга, достижения
	var tw: Tween = create_tween()
	for entry in values:
		var lab: Label = entry[0]
		var target: int = entry[1]
		tw.tween_method(func(x: float) -> void: lab.text = str(int(x)), 0.0, float(target), 0.35)
		tw.tween_callback(func() -> void: ProceduralSFX.play("click", -4.0))
	tw.tween_callback(func() -> void:
		ProceduralSFX.play("stamp")
		rk.modulate.a = 1.0)
	tw.tween_property(rk, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _slam())
	for i in range(stars.get_child_count()):
		var st: Control = stars.get_child(i)
		tw.tween_callback(func() -> void: ProceduralSFX.play("combo", -2.0, 0.8 + 0.2 * float(i)))
		tw.tween_property(st, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for al2 in ach_labels:
		tw.tween_callback(func() -> void: ProceduralSFX.play("achieve", -4.0))
		tw.tween_property(al2, "modulate:a", 1.0, 0.3)


func _slam() -> void:
	var tw: Tween = create_tween()
	var base: Vector2 = _panel.position
	tw.tween_property(_panel, "position", base + Vector2(0, 14), 0.04)
	tw.tween_property(_panel, "position", base + Vector2(0, -8), 0.05)
	tw.tween_property(_panel, "position", base, 0.06)


func show_defeat(reason: String) -> void:
	_clear()
	_title("МИССИЯ ПРОВАЛЕНА", UITheme.RED, 42)
	var l := UITheme.label(reason, 24, UITheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(l)
	var h := UITheme.label("Игра детерминирована: в провале виноват расчёт, а не случай. Откат хода вернёт вас на такт назад.", 16, UITheme.DIM)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(h)
	_add_button("БЫСТРЫЙ РЕСТАРТ  [R]", "restart", UITheme.RED)
	_add_button("ОТКАТИТЬ ХОД  [Backspace]", "undo", UITheme.AMBER)
	_add_button("В ГЛАВНОЕ МЕНЮ", "menu", UITheme.DIM)
	_open(UITheme.RED)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: InputEventKey = event
	match k.physical_keycode:
		KEY_R:
			for b in _buttons:
				if "[R]" in b.text:
					b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
		KEY_BACKSPACE:
			for b in _buttons:
				if "[Backspace]" in b.text:
					b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
		KEY_ESCAPE:
			for b in _buttons:
				if "[Esc]" in b.text:
					b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
		KEY_M:
			for b in _buttons:
				if "[M]" in b.text:
					b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
