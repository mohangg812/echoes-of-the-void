# res://ui/HUD.gd
# Тактический интерфейс: три верхние плашки (миссия / статус тревоги и заметность / цель и стиль),
# левая колонка (справка + радиопереговоры), правая (радар, задачи, журнал), нижняя панель снаряжения.
class_name HUD
extends CanvasLayer

var level_label: Label
var turn_label: Label
var par_text: Label
var status_label: Label
var meter_label: Label
var goal_label: Label
var stat_label: Label
var combo_label: Label
var msg_label: Label
var tl_panel: NeonPanel
var tc_panel: NeonPanel
var tr_panel: NeonPanel
var bottom_panel: NeonPanel
var loadout: LoadoutBar
var minimap: Minimap
var dialogue: DialogueBox
var feed: EventFeed
var help_panel: NeonPanel
var tasks_panel: NeonPanel
var task_labels: Array[Label] = []
var _toast_root: Control
var _msg_tween: Tween
var _t: float = 0.0
var _alarm_pulse: bool = false
var _vis_target: float = 0.0
var _vis_shown: float = 0.0
var _turn: int = 0
var _par: int = 1
var _cool: int = 0
var _alarm: bool = false
var _combo: int = 0
var _combo_left: float = 0.0
var _meter_draw: Control
var _par_draw: Control
var _combo_draw: Control
var _chips_draw: Control
var _sim: TurnManager


func _ready() -> void:
	layer = 10
	_build_top()
	_build_left()
	_build_right()
	_build_bottom()
	_toast_root = Control.new()
	_toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_root)
	msg_label = UITheme.label("", 22, UITheme.AMBER, true)
	msg_label.position = Vector2(330, 84)
	msg_label.size = Vector2(1260, 30)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.modulate.a = 0.0
	add_child(msg_label)


func _panel(pos: Vector2, sz: Vector2, accent: Color = UITheme.CYAN) -> NeonPanel:
	var p := NeonPanel.new()
	p.position = pos
	p.size = sz
	p.accent = accent
	add_child(p)
	return p


func _add_label(parent: Control, text: String, size: int, color: Color, pos: Vector2, bold: bool = false) -> Label:
	var l: Label = UITheme.label(text, size, color, bold)
	l.position = pos
	parent.add_child(l)
	return l


func _build_top() -> void:
	tl_panel = _panel(Vector2(20, 8), Vector2(600, 66))
	level_label = _add_label(tl_panel, "", 14, UITheme.DIM, Vector2(20, 6))
	turn_label = _add_label(tl_panel, "ХОД 000", 28, UITheme.CYAN, Vector2(20, 24), true)
	par_text = _add_label(tl_panel, "ПАР 0", 13, UITheme.DIM, Vector2(300, 8))
	_par_draw = Control.new()
	_par_draw.position = Vector2(300, 30)
	_par_draw.size = Vector2(280, 22)
	_par_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_par_draw.draw.connect(_draw_par)
	tl_panel.add_child(_par_draw)

	tc_panel = _panel(Vector2(660, 6), Vector2(600, 70), UITheme.CYAN)
	status_label = _add_label(tc_panel, "СТЕЛС: ТИШИНА", 26, UITheme.CYAN, Vector2(0, 2), true)
	status_label.size = Vector2(600, 32)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_label = _add_label(tc_panel, "ЗАМЕТНОСТЬ", 11, UITheme.DIM, Vector2(18, 44))
	_meter_draw = Control.new()
	_meter_draw.position = Vector2(112, 44)
	_meter_draw.size = Vector2(470, 16)
	_meter_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_draw.draw.connect(_draw_meter)
	tc_panel.add_child(_meter_draw)

	tr_panel = _panel(Vector2(1300, 8), Vector2(600, 66), UITheme.GOLD)
	goal_label = _add_label(tr_panel, "", 17, UITheme.GOLD, Vector2(18, 5), true)
	stat_label = _add_label(tr_panel, "", 15, UITheme.TEXT, Vector2(18, 36))
	_chips_draw = Control.new()
	_chips_draw.position = Vector2(300, 6)
	_chips_draw.size = Vector2(120, 56)
	_chips_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips_draw.draw.connect(_draw_chips)
	tr_panel.add_child(_chips_draw)
	combo_label = _add_label(tr_panel, "", 22, UITheme.AMBER, Vector2(430, 4), true)
	_combo_draw = Control.new()
	_combo_draw.position = Vector2(430, 40)
	_combo_draw.size = Vector2(150, 12)
	_combo_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_draw.draw.connect(_draw_combo)
	tr_panel.add_child(_combo_draw)


func _build_left() -> void:
	help_panel = _panel(Vector2(20, 96), Vector2(300, 440), UITheme.CYAN)
	help_panel.title = "УПРАВЛЕНИЕ"
	var lines: Array = [
		["WASD / ←↑↓→", "шаг"], ["Space / Z", "ждать такт"], ["Shift + шаг", "рывок на 2"],
		["E", "рубильник/терминал"], ["F", "шокер со спины"], ["1  ДЫМ", "облако 3x3"],
		["2  МАНОК", "шум R=4"], ["3  ЭМИ", "вырубить технику"], ["4  ПЛАЩ", "невидим 2 хода"],
		["Backspace", "откат хода"], ["R", "рестарт"], ["T", "рамки конусов"], ["H", "скрыть справку"],
		["Esc / M", "пауза / звук"],
	]
	var y: float = 18.0
	for l in lines:
		_add_label(help_panel, String(l[0]), 14, UITheme.AMBER, Vector2(14, y), true)
		_add_label(help_panel, String(l[1]), 14, UITheme.TEXT, Vector2(150, y))
		y += 22.0
	var legend: Label = _add_label(help_panel, "ЯРКИЕ зоны — угроза СЛЕДУЮЩЕГО такта.\nКрасный — тревога, жёлтый — подозрение.", 12, UITheme.DIM, Vector2(14, y + 8))
	legend.size = Vector2(272, 60)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue = DialogueBox.new()
	dialogue.position = Vector2(20, 770)
	add_child(dialogue)


func _build_right() -> void:
	var mp: NeonPanel = _panel(Vector2(1600, 96), Vector2(300, 230), UITheme.CYAN)
	mp.title = "РАДАР"
	minimap = Minimap.new()
	minimap.position = Vector2(8, 8)
	minimap.size = Vector2(284, 214)
	mp.add_child(minimap)
	tasks_panel = _panel(Vector2(1600, 346), Vector2(300, 150), UITheme.GOLD)
	tasks_panel.title = "ЗАДАЧИ"
	for i in range(5):
		var l: Label = _add_label(tasks_panel, "", 15, UITheme.TEXT, Vector2(14, 14 + i * 26))
		task_labels.append(l)
	var fp: NeonPanel = _panel(Vector2(1600, 516), Vector2(300, 440), UITheme.CYAN)
	fp.title = "ЖУРНАЛ"
	feed = EventFeed.new()
	feed.position = Vector2(10, 10)
	feed.size = Vector2(280, 420)
	fp.add_child(feed)


func _build_bottom() -> void:
	bottom_panel = _panel(Vector2(330, 972), Vector2(1260, 98), UITheme.CYAN)
	loadout = LoadoutBar.new()
	loadout.position = Vector2(330, 972)
	loadout.size = Vector2(1260, 98)
	add_child(loadout)


# ───────────────────────── отрисовка встроенных виджетов ─────────────────────────

func _draw_par() -> void:
	var w: float = _par_draw.size.x
	var k: float = clampf(float(_turn) / float(maxi(_par, 1)), 0.0, 1.0)
	_par_draw.draw_rect(Rect2(0, 6, w, 10), Color(0.05, 0.1, 0.15, 0.9))
	var col: Color = Color(0.2, 1.1, 1.3).lerp(Color(2.0, 1.2, 0.1), clampf((k - 0.6) / 0.4, 0.0, 1.0))
	if _turn > _par:
		col = Color(2.0, 0.2, 0.3)
	var segs: int = 28
	for i in range(segs):
		if float(i) / float(segs) < k:
			_par_draw.draw_rect(Rect2(i * (w / segs) + 1, 7, w / segs - 2, 8), col)
	_par_draw.draw_rect(Rect2(0, 6, w, 10), Color(0.0, 0.5, 0.6, 0.7), false, 1.0)


func _draw_meter() -> void:
	var w: float = _meter_draw.size.x
	var segs: int = 24
	var level: float = _vis_shown
	var is_cool: bool = _alarm
	if is_cool:
		level = float(_cool) / 6.0
	for i in range(segs):
		var k: float = float(i) / float(segs)
		var on: bool = k < level
		var col: Color
		if is_cool:
			col = Color(2.2, 0.15, 0.25)
		else:
			col = Color(0.2, 1.2, 1.4).lerp(Color(2.0, 1.4, 0.1), clampf(k * 2.0, 0.0, 1.0)).lerp(Color(2.2, 0.2, 0.3), clampf((k - 0.5) * 2.0, 0.0, 1.0))
		var r := Rect2(i * (w / segs) + 1, 2, w / segs - 2, 12)
		if on:
			_meter_draw.draw_rect(r, col)
		else:
			_meter_draw.draw_rect(r, Color(0.08, 0.14, 0.2, 0.9))


func _draw_chips() -> void:
	if _sim == null:
		return
	var total: int = _sim.chips_total
	for i in range(total):
		var got: bool = i < _sim.player.chips
		var r := Rect2(i * 38, 10, 30, 36)
		_chips_draw.draw_rect(r, Color(0.9, 0.7, 0.1, 0.95) if got else Color(0.2, 0.25, 0.3, 0.5))
		_chips_draw.draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(18, 14)), Color(0.2, 1.4, 1.6, 0.95) if got else Color(0.1, 0.15, 0.2))
		_chips_draw.draw_rect(r, Color(1, 1, 1, 0.4), false, 1.0)


func _draw_combo() -> void:
	var k: float = clampf(_combo_left / 6.0, 0.0, 1.0)
	_combo_draw.draw_rect(Rect2(0, 0, 150, 10), Color(0.1, 0.08, 0.02, 0.8))
	if k > 0.0:
		_combo_draw.draw_rect(Rect2(0, 0, 150.0 * k, 10), Color(2.0, 1.3, 0.1))


# ───────────────────────── обновление ─────────────────────────

func set_level(title: String) -> void:
	level_label.text = title


func setup(sim: TurnManager) -> void:
	_sim = sim
	loadout.setup(sim)
	minimap.setup(sim)
	feed.clear_all()
	dialogue.clear()


func set_hint(_text: String) -> void:
	pass


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func update_from(sim: TurnManager, danger_here: int = 0) -> void:
	_sim = sim
	_turn = sim.turn_number
	_par = int(sim.level_data.get("par_turns", 1))
	turn_label.text = "ХОД %03d" % sim.turn_number
	par_text.text = "ПАР %d" % _par
	var al: AlarmManager = sim.alarm
	_alarm_pulse = false
	_alarm = al.is_alarm()
	_cool = al.cooldown
	match al.state:
		AlarmManager.State.STEALTH:
			status_label.text = "СТЕЛС: ТИШИНА"
			status_label.add_theme_color_override("font_color", UITheme.CYAN)
			meter_label.text = "ЗАМЕТНОСТЬ"
			tc_panel.accent = UITheme.CYAN
		AlarmManager.State.SUSPICION:
			status_label.text = "ПОДОЗРЕНИЕ"
			status_label.add_theme_color_override("font_color", UITheme.AMBER)
			meter_label.text = "ЗАМЕТНОСТЬ"
			tc_panel.accent = UITheme.AMBER
		AlarmManager.State.ALARM_ACTIVE:
			var n: int = al.cooldown
			status_label.text = "ТРЕВОГА!  СБРОС ЧЕРЕЗ %d %s" % [n, _turns_word(n)]
			meter_label.text = "СБРОС"
			tc_panel.accent = UITheme.RED
			_alarm_pulse = true
	_vis_target = 0.0 if danger_here == 0 else (0.5 if danger_here == 1 else 1.0)
	if al.state == AlarmManager.State.SUSPICION:
		_vis_target = maxf(_vis_target, 0.35)
	if sim.player.has_gold:
		goal_label.text = "ЯДРО УКРАДЕНО — К ВЫХОДУ!"
	else:
		goal_label.text = "ЦЕЛЬ: ЯДРО ДАННЫХ"
	stat_label.text = "СЧЁТ %06d" % sim.player.score
	_combo = sim.combo if sim.turn_number - sim.last_style_turn <= 6 else 0
	_combo_left = float(6 - (sim.turn_number - sim.last_style_turn)) if _combo > 0 else 0.0
	combo_label.text = "СТИЛЬ x%d" % sim.combo_mult() if _combo > 0 else ""
	_update_tasks(sim)
	_chips_draw.queue_redraw()
	_combo_draw.queue_redraw()
	_par_draw.queue_redraw()


func _update_tasks(sim: TurnManager) -> void:
	var items: Array = []
	var needed: Array[String] = []
	for d in sim.doors:
		if d.required_keycard != "" and not needed.has(d.required_keycard):
			needed.append(d.required_keycard)
	for c in needed:
		items.append([sim.player.keycards.has(c), "Ключ-карта: %s" % TurnManager.card_name(c).to_lower()])
	for sw in sim.switches:
		items.append([sw.on, "Рубильник: %s" % sw.description.to_lower().substr(0, 18)])
		break
	items.append([sim.player.has_gold, "Украсть Ядро данных"])
	if sim.chips_total > 0:
		items.append([sim.player.chips >= sim.chips_total, "Чипы: %d/%d" % [sim.player.chips, sim.chips_total]])
	items.append([sim.result == "won", "Эвакуация"])
	for i in range(task_labels.size()):
		if i < items.size():
			var done: bool = items[i][0]
			task_labels[i].text = ("[x] " if done else "[ ] ") + String(items[i][1])
			task_labels[i].add_theme_color_override("font_color", UITheme.GREEN if done else UITheme.TEXT)
		else:
			task_labels[i].text = ""


func _turns_word(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "ХОД"
	if n % 10 >= 2 and n % 10 <= 4 and not (n % 100 >= 12 and n % 100 <= 14):
		return "ХОДА"
	return "ХОДОВ"


func pulse_panels(color: Color) -> void:
	for p in [tl_panel, tc_panel, tr_panel, bottom_panel]:
		p.flash = 1.0


func _process(delta: float) -> void:
	_t += delta
	_vis_shown = lerpf(_vis_shown, _vis_target, minf(1.0, delta * 7.0))
	_meter_draw.queue_redraw()
	if _alarm_pulse:
		var k: float = 0.5 + 0.5 * sin(_t * 8.0)
		status_label.add_theme_color_override("font_color", UITheme.RED.lerp(Color(1.0, 0.75, 0.75), k * 0.6))
		tc_panel.flash = 0.3 + 0.3 * k


func flash_message(text: String, color: Color = UITheme.AMBER) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", color)
	msg_label.modulate.a = 1.0
	if _msg_tween != null and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.7)
	_msg_tween.tween_property(msg_label, "modulate:a", 0.0, 0.5)


# Большая надпись-баннер, въезжающая с глитчем (ТРЕВОГА!, ПРОТОКОЛ УСИЛЕНИЯ...).
func toast(text: String, color: Color, big: bool = false) -> void:
	var pan := NeonPanel.new()
	pan.accent = color
	pan.fill = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.88)
	pan.size = Vector2(900 if big else 640, 86 if big else 64)
	pan.position = Vector2(-1000, 300)
	_toast_root.add_child(pan)
	var l: Label = UITheme.label(text, 40 if big else 28, color, true)
	l.size = pan.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	pan.add_child(l)
	var target_x: float = 960.0 - pan.size.x * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(pan, "position:x", target_x + 30.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(pan, "position:x", target_x, 0.08)
	tw.tween_callback(func() -> void: pan.flash = 1.0)
	tw.tween_interval(1.1)
	tw.tween_property(pan, "position:x", 2000.0, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(pan.queue_free)
	# дрожь текста
	var sh: Tween = create_tween().set_loops(10)
	sh.tween_property(l, "position:x", 5.0, 0.03)
	sh.tween_property(l, "position:x", -4.0, 0.03)
	sh.tween_property(l, "position:x", 0.0, 0.03)
