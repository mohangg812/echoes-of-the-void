# res://ui/MainMenu.gd
# Главное меню: глитч-титул, синтвейв-горизонт, демо-сценка кражи, выбор миссии с превью карт, достижения.
extends Control

var _t: float = 0.0
var _screens: Dictionary = {}
var _current: String = "main"
var _first_button: Button
var _title: TitleDraw
var _busy: bool = false
var _demo: Control


# ───────────────────────── фон ─────────────────────────

class MenuBackground extends Control:
	var t: float = 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#05070C"))
		var hz: float = size.y * 0.58
		# градиент неба
		for i in range(14):
			var k: float = float(i) / 14.0
			draw_rect(Rect2(0, hz - 260.0 + k * 260.0, size.x, 20.0), Color(0.55, 0.05, 0.35, 0.02 + 0.05 * k))
		# солнце-полоса
		var sc := Vector2(size.x * 0.68, hz - 40.0)
		for i in range(10):
			var r: float = 150.0 - float(i) * 3.0
			draw_circle(sc, r, Color(1.0, 0.25, 0.5, 0.03))
		for i in range(7):
			draw_rect(Rect2(sc.x - 150, sc.y + 10 + i * 12, 300, 2 + i), Color(0.03, 0.02, 0.06, 1))
		# перспективная сетка
		var vp := Vector2(size.x * 0.5, hz)
		var col: Color = Color(0.0, 0.8, 0.9, 0.22)
		for i in range(-24, 25):
			var bx: float = size.x * 0.5 + float(i) * 150.0
			draw_line(vp, Vector2(bx, size.y), col, 1.0)
		var off: float = fmod(t * 0.45, 1.0)
		for j in range(14):
			var k2: float = (float(j) + off) / 14.0
			var y: float = hz + (size.y - hz) * pow(k2, 2.2)
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.0, 0.8, 0.9, 0.08 + 0.25 * k2), 1.0 + 1.5 * k2)
		draw_line(Vector2(0, hz), Vector2(size.x, hz), Color(1.2, 0.3, 0.8, 0.6), 2.0)
		# цифровой дождь
		var f: Font = UITheme.font()
		var cols: int = int(size.x / 26.0)
		for ci in range(cols):
			var cx: float = float(ci) * 26.0 + 8.0
			var speed: float = 50.0 + float((ci * 37) % 110)
			var head: float = fmod(t * speed + float((ci * 911) % 1500), size.y + 300.0) - 150.0
			for k in range(8):
				var gy: float = head - float(k) * 17.0
				if gy < 0.0 or gy > hz:
					continue
				var ch: String = "01ABCDEF<>/#%"[(ci * 7 + k * 3 + int(t * (3.0 + float(ci % 4)))) % 13]
				var a: float = 0.20 * (1.0 - float(k) / 8.0)
				draw_string(f, Vector2(cx, gy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.2, 1.0, 0.9, a) if k > 0 else Color(0.8, 1.7, 1.6, 0.4))
		# плывущие конусы охранников
		var cx1: float = fmod(t * 70.0, size.x + 700.0) - 350.0
		var cy1: float = hz - 120.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx1, cy1), Vector2(cx1 + 320, cy1 - 140), Vector2(cx1 + 320, cy1 + 140)]), Color(1.0, 0.0, 0.24, 0.07))
		draw_circle(Vector2(cx1, cy1), 9.0, Color(2.0, 0.1, 0.25))
		var cx2: float = size.x - fmod(t * 45.0, size.x + 600.0) + 300.0
		var cy2: float = size.y * 0.18
		draw_colored_polygon(PackedVector2Array([Vector2(cx2, cy2), Vector2(cx2 - 280, cy2 - 110), Vector2(cx2 - 280, cy2 + 110)]), Color(1.0, 0.72, 0.0, 0.06))
		draw_circle(Vector2(cx2, cy2), 8.0, Color(2.0, 1.3, 0.1))


# ───────────────────────── титул с глитчем ─────────────────────────

class TitleDraw extends Control:
	var t: float = 0.0
	var line1: String = "ТЕНЕВОЙ ВОР"
	var line2: String = "ПОБЕГ ПО ПИКСЕЛЯМ"
	var tag: String = "Один неверный шаг — и ты труп. Рассчитай тайминг, обмани ИИ, укради золото."
	var _glitch: float = 0.0

	func _process(d: float) -> void:
		t += d
		_glitch = maxf(0.0, _glitch - d * 3.0)
		if fmod(t, 3.2) < 0.06:
			_glitch = 1.0
		queue_redraw()

	func _draw() -> void:
		var f: Font = UITheme.font(true)
		var fs: int = 92
		var base := Vector2(0, 90)
		var j: float = _glitch * 14.0
		var jy: float = sin(t * 80.0) * _glitch * 4.0
		var shown: int = clampi(int(t * 22.0), 0, line1.length())
		var s1: String = line1.substr(0, shown)
		draw_string(f, base + Vector2(-4.0 - j, jy), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(2.0, 0.1, 0.4, 0.75))
		draw_string(f, base + Vector2(4.0 + j, -jy), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 1.6, 2.0, 0.75))
		draw_string(f, base, s1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.3, 1.35, 1.4))
		if shown >= line1.length():
			var shown2: int = clampi(int((t - 0.6) * 26.0), 0, line2.length())
			draw_string(f, Vector2(4, 140), line2.substr(0, shown2), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(2.0, 1.4, 0.2))
			var shown3: int = clampi(int((t - 1.4) * 60.0), 0, tag.length())
			draw_string(UITheme.font(), Vector2(4, 176), tag.substr(0, shown3), HORIZONTAL_ALIGNMENT_LEFT, 900, 17, Color(0.6, 0.8, 0.9, 0.9))
		# горизонтальные глитч-полосы
		if _glitch > 0.1:
			for i in range(3):
				var yy: float = fmod(float(i) * 31.7 + t * 300.0, 120.0)
				draw_rect(Rect2(0, yy, 700, 4), Color(0.0, 1.8, 2.0, 0.4 * _glitch))


# ───────────────────────── демо-сценка кражи ─────────────────────────

class DemoStage extends Control:
	var t: float = 0.0
	const LOOP: float = 11.0
	var tile: Texture2D
	var wall: Texture2D
	var tex_guard_key: Texture2D
	var tex_guard: Texture2D
	var tex_player: Texture2D
	var tex_glow: Texture2D

	func _init() -> void:
		tile = UITheme.tex("tiles/tile_floor_cyber")
		wall = UITheme.tex("tiles/tile_wall_solid")
		tex_guard_key = UITheme.tex("enemies/guard_standard_keycard")
		tex_guard = UITheme.tex("enemies/guard_standard_patrol")
		tex_player = UITheme.tex("player/player_idle_topdown")
		tex_glow = UITheme.tex("security/light_radial_glow")

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var tt: float = fmod(t, LOOP)
		var n: int = int(size.x / 48.0) + 2
		for i in range(n):
			draw_texture_rect(tile, Rect2(i * 48, 48, 48, 48), false, Color(2.0, 2.1, 2.3))
			draw_texture_rect(wall, Rect2(i * 48, 0, 48, 48), false, Color(0.6, 0.7, 0.8))
			draw_texture_rect(wall, Rect2(i * 48, 96, 48, 48), false, Color(0.6, 0.7, 0.8))
		var gx: float = 60.0 + (tt / LOOP) * (size.x - 300.0)
		var gy: float = 72.0
		var gap: float = lerpf(330.0, 50.0, clampf(tt / 6.5, 0.0, 1.0))
		var tx: float = gx - gap
		var stolen: bool = tt > 6.8
		# конус охранника
		var cone := PackedVector2Array([Vector2(gx, gy), Vector2(gx + 200, gy - 80), Vector2(gx + 200, gy + 80)])
		draw_colored_polygon(cone, Color(1.0, 0.0, 0.24, 0.16))
		draw_polyline(PackedVector2Array([cone[1], cone[0], cone[2]]), Color(2.0, 0.2, 0.4, 0.5), 1.5)
		var gtex: Texture2D = tex_guard if stolen else tex_guard_key
		draw_set_transform(Vector2(gx, gy), 0.0, Vector2.ONE)
		draw_texture_rect(gtex, Rect2(-24, -24, 48, 48), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ptex: Texture2D = tex_player
		var bob: float = sin(tt * 9.0) * 1.5
		draw_texture_rect(tex_glow, Rect2(tx - 50, gy - 50 + bob, 100, 100), false, Color(0.2, 1.0, 1.4, 0.5))
		draw_texture_rect(ptex, Rect2(tx - 24, gy - 24 + bob, 48, 48), false)
		# кража: карта летит от охранника к вору
		if tt > 6.8 and tt < 7.6:
			var k: float = (tt - 6.8) / 0.8
			var cp: Vector2 = Vector2(gx, gy).lerp(Vector2(tx, gy - 30.0), k) + Vector2(0, -sin(k * PI) * 30.0)
			draw_rect(Rect2(cp.x - 7, cp.y - 10, 14, 20), Color(2.4, 0.3, 0.4))
			draw_arc(Vector2(gx, gy), k * 70.0, 0, TAU, 32, Color(2.0, 0.4, 0.5, 1.0 - k), 2.0)
		if tt > 7.0 and tt < 9.0:
			var a: float = 1.0 - (tt - 7.0) / 2.0
			draw_string(UITheme.font(true), Vector2(tx - 60, gy - 44 - (tt - 7.0) * 14.0), "КАРМАННИК +100", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(2.0, 1.5, 0.3, a))
		if tt < 3.5 and tt > 0.5:
			draw_string(UITheme.font(), Vector2(tx - 30, gy + 58), "заходи со спины", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.9, 1.0, 0.7))


# ───────────────────────── построение экранов ─────────────────────────

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := MenuBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = TitleDraw.new()
	_title.position = Vector2(110, 60)
	_title.size = Vector2(1000, 200)
	add_child(_title)
	var demo := DemoStage.new()
	_demo = demo
	demo.position = Vector2(80, 720)
	demo.size = Vector2(1100, 144)
	demo.clip_contents = true
	add_child(demo)
	_build_main()
	_build_levels()
	_build_achievements()
	_show("main", false)
	if GameState.profile_warning != "":
		_show_profile_warning()
	var cl := CanvasLayer.new()
	cl.layer = 60
	add_child(cl)
	var crt := ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://vfx/shaders/crt_cyberpunk.gdshader") as Shader
	crt.material = mat
	cl.add_child(crt)
	ProceduralSFX.stop_siren()
	ProceduralSFX.start_music()
	ProceduralSFX.play("boot")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot(a.substr(7))
		elif a.begins_with("--screen="):
			_show(a.substr(9), false)


func _shot(path: String) -> void:
	await get_tree().create_timer(2.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("скриншот меню: ", path)
	get_tree().quit()


func _btn(text: String, accent: Color, cb: Callable, size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b, size, accent)
	b.custom_minimum_size = Vector2(440, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		ProceduralSFX.play("select")
		cb.call())
	b.mouse_entered.connect(func() -> void:
		ProceduralSFX.play("hover", -6.0)
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "position:x", 14.0, 0.08))
	b.mouse_exited.connect(func() -> void:
		var tw2: Tween = b.create_tween()
		tw2.tween_property(b, "position:x", 0.0, 0.1))
	b.focus_entered.connect(func() -> void: ProceduralSFX.play("hover", -6.0))
	return b


func _build_main() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(110, 290)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_screens["main"] = box
	var next_idx: int = clampi(GameState.unlocked - 1, 0, GameState.LEVEL_FILES.size() - 1)
	var checkpoint: Dictionary = RunCheckpoint.read()
	var resume_button: Button = null
	if not checkpoint.is_empty() and int(checkpoint["level"]) < GameState.unlocked:
		var index: int = int(checkpoint["level"])
		resume_button = _btn("↻  ВОЗОБНОВИТЬ МИССИЮ %d" % (index + 1), UITheme.GREEN, func() -> void:
			GameState.resume_requested = true
			_start(index), 24)
		box.add_child(resume_button)
	var cont: Button = _btn("▶  %s" % ("ПРОДОЛЖИТЬ: МИССИЯ %d" % (next_idx + 1) if GameState.unlocked > 1 else "НАЧАТЬ ИГРУ"), UITheme.GREEN, func() -> void: _start(next_idx), 28)
	box.add_child(cont)
	_first_button = resume_button if resume_button != null else cont
	box.add_child(_btn("▦  ВЫБОР МИССИИ", UITheme.CYAN, func() -> void: _show("levels", true)))
	box.add_child(_btn("★  ДОСТИЖЕНИЯ  %d/%d" % [GameState.achievements.size(), GameState.ACHIEVEMENTS.size()], UITheme.GOLD, func() -> void: _show("ach", true)))
	box.add_child(_btn("✕  ВЫХОД", UITheme.RED, func() -> void: get_tree().quit()))
	# панель инструктажа справа
	var p := NeonPanel.new()
	p.position = Vector2(1180, 250)
	p.size = Vector2(640, 440)
	p.title = "ИНСТРУКТАЖ"
	add_child(p)
	_screens["help"] = p
	var lines: Array = [
		["WASD / стрелки", "шаг (1 действие = 1 такт мира)"],
		["Space / Z", "пропуск хода — переждать патруль"],
		["Shift + шаг", "рывок на 2 клетки (шумно)"],
		["E", "взломать рубильник / терминал"],
		["F", "оглушить охранника со спины"],
		["1  ДЫМ", "облако 3x3: слепит камеры, гасит лазеры"],
		["2  МАНОК", "шумовая граната — охрана идёт на звук"],
		["3  ЭМИ", "вырубает технику и оглушает охрану"],
		["4  ПЛАЩ", "невидимость для конусов на 2 хода"],
		["Backspace", "тактический откат хода"],
		["R / Esc / M", "рестарт / пауза / звук"],
	]
	var y: float = 22.0
	for l in lines:
		var a: Label = UITheme.label(String(l[0]), 17, UITheme.AMBER, true)
		a.position = Vector2(20, y)
		p.add_child(a)
		var b: Label = UITheme.label(String(l[1]), 16, UITheme.TEXT)
		b.position = Vector2(210, y)
		p.add_child(b)
		y += 28.0
	var legend: Label = UITheme.label("Яркий красный — прямое обнаружение (тревога).\nЖёлтый — подозрение. Зоны — прогноз на случай ожидания.", 15, UITheme.TEXT)
	legend.position = Vector2(20, y + 10)
	p.add_child(legend)
	var credits: Label = UITheme.label("Ассеты: github.com/mohangg812/echoes-of-the-void", 13, UITheme.DIM)
	credits.position = Vector2(20, y + 70)
	p.add_child(credits)


func _show_profile_warning() -> void:
	if GameState.needs_profile_reset:
		var confirm := ConfirmationDialog.new()
		confirm.title = "Восстановление профиля"
		confirm.dialog_text = GameState.profile_warning
		confirm.ok_button_text = "Создать новый"
		confirm.cancel_button_text = "Без записи"
		confirm.confirmed.connect(func() -> void:
			if GameState.confirm_new_profile():
				ProceduralSFX.apply_audio_levels()
				SceneTransition.change_scene("res://ui/MainMenu.tscn"))
		add_child(confirm)
		confirm.popup_centered()
	else:
		var notice := AcceptDialog.new()
		notice.title = "Восстановление профиля"
		notice.dialog_text = GameState.profile_warning
		GameState.profile_warning = ""
		add_child(notice)
		notice.popup_centered()


func _build_levels() -> void:
	var root := Control.new()
	root.position = Vector2(80, 110)
	root.size = Vector2(1760, 800)
	add_child(root)
	_screens["levels"] = root
	var head: Label = UITheme.label("ВЫБОР МИССИИ", 36, UITheme.CYAN, true)
	head.position = Vector2(20, -10)
	root.add_child(head)
	var n: int = GameState.LEVEL_FILES.size()
	for i in range(n):
		var col: int = i % 4
		var row: int = i / 4
		var card := NeonPanel.new()
		card.size = Vector2(410, 300)
		card.position = Vector2(20 + col * 430, 50 + row * 320)
		var unlocked: bool = i < GameState.unlocked
		card.accent = UITheme.CYAN if unlocked else Color(0.3, 0.35, 0.42)
		root.add_child(card)
		var data: Dictionary = _read_level(i)
		var pv := LevelPreview.new()
		pv.position = Vector2(14, 14)
		pv.size = Vector2(382, 170)
		pv.locked = not unlocked
		pv.setup(data)
		card.add_child(pv)
		var num: Label = UITheme.label("%02d" % (i + 1), 34, UITheme.AMBER if unlocked else UITheme.DIM, true)
		num.position = Vector2(16, 188)
		card.add_child(num)
		var title: String = String(data.get("title", "")).replace("ОПЕРАЦИЯ %02d: " % (i + 1), "")
		var tl: Label = UITheme.label(title if unlocked else "ЗАБЛОКИРОВАНО", 17, UITheme.TEXT if unlocked else UITheme.DIM, true)
		tl.position = Vector2(76, 190)
		tl.size = Vector2(250, 50)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(tl)
		var rank: String = GameState.best_rank(i)
		if rank != "":
			var rc: Color = {"S": UITheme.GOLD, "A": UITheme.GREEN, "B": UITheme.CYAN, "C": UITheme.AMBER}[rank]
			var rl: Label = UITheme.label(rank, 56, rc, true)
			rl.position = Vector2(336, 178)
			card.add_child(rl)
			var best: Dictionary = GameState.best.get(str(i + 1), {})
			var bl: Label = UITheme.label("лучшее: %d ходов" % int(best.get("turns", 0)), 14, UITheme.DIM)
			bl.position = Vector2(16, 258)
			card.add_child(bl)
		elif unlocked:
			var nl: Label = UITheme.label("не пройдено", 14, UITheme.DIM)
			nl.position = Vector2(16, 258)
			card.add_child(nl)
		var btn := Button.new()
		btn.flat = true
		btn.size = card.size
		btn.disabled = not unlocked
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_stylebox_override("focus", UITheme.box(UITheme.AMBER, Color(0, 0, 0, 0), 3, 2))
		var idx: int = i
		btn.pressed.connect(func() -> void:
			ProceduralSFX.play("select")
			_start(idx))
		btn.mouse_entered.connect(func() ->void:
			if unlocked:
				ProceduralSFX.play("hover", -6.0)
				card.flash = 1.0
				var tw: Tween = card.create_tween()
				tw.tween_property(card, "position:y", 50.0 + row * 320.0 - 8.0, 0.1))
		btn.mouse_exited.connect(func() -> void:
			var tw2: Tween = card.create_tween()
			tw2.tween_property(card, "position:y", 50.0 + row * 320.0, 0.1))
		card.add_child(btn)
	var back: Button = _btn("◀  НАЗАД", UITheme.DIM, func() -> void: _show("main", true), 22)
	back.custom_minimum_size = Vector2(240, 52)
	back.position = Vector2(20, 700)
	root.add_child(back)


func _read_level(i: int) -> Dictionary:
	var f: FileAccess = FileAccess.open(GameState.LEVEL_FILES[i], FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _build_achievements() -> void:
	var root := Control.new()
	root.position = Vector2(80, 130)
	root.size = Vector2(1760, 800)
	add_child(root)
	_screens["ach"] = root
	var head: Label = UITheme.label("ДОСТИЖЕНИЯ  %d / %d" % [GameState.achievements.size(), GameState.ACHIEVEMENTS.size()], 36, UITheme.GOLD, true)
	head.position = Vector2(20, -10)
	root.add_child(head)
	var i: int = 0
	for id in GameState.ACHIEVEMENTS:
		var info: Array = GameState.ACHIEVEMENTS[id]
		var got: bool = GameState.achievements.has(id)
		var card := NeonPanel.new()
		card.size = Vector2(540, 90)
		card.position = Vector2(20 + (i % 3) * 560, 50 + (i / 3) * 106)
		card.accent = UITheme.GOLD if got else Color(0.3, 0.35, 0.42)
		root.add_child(card)
		var star: Label = UITheme.label("★" if got else "☆", 40, UITheme.GOLD if got else UITheme.DIM, true)
		star.position = Vector2(16, 18)
		card.add_child(star)
		var nm: Label = UITheme.label(String(info[0]), 20, UITheme.GOLD if got else UITheme.DIM, true)
		nm.position = Vector2(72, 12)
		card.add_child(nm)
		var ds: Label = UITheme.label(String(info[1]), 15, UITheme.TEXT if got else UITheme.DIM)
		ds.position = Vector2(72, 44)
		ds.size = Vector2(450, 40)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(ds)
		i += 1
	var back: Button = _btn("◀  НАЗАД", UITheme.DIM, func() -> void: _show("main", true), 22)
	back.custom_minimum_size = Vector2(240, 52)
	back.position = Vector2(20, 700)
	root.add_child(back)


func _show(name: String, animate: bool) -> void:
	_current = name
	for k in ["main", "levels", "ach"]:
		var n: Control = _screens[k]
		var on: bool = k == name
		n.visible = on
		if on and animate:
			n.modulate.a = 0.0
			var tw: Tween = create_tween()
			tw.tween_property(n, "modulate:a", 1.0, 0.25)
	(_screens["help"] as Control).visible = name == "main"
	_title.visible = name == "main"
	_demo.visible = name == "main"
	if name == "main" and _first_button != null:
		_first_button.call_deferred("grab_focus")
	elif name != "main":
		var n2: Control = _screens[name]
		for c in n2.get_children():
			if c is NeonPanel:
				for cc in c.get_children():
					if cc is Button and not (cc as Button).disabled:
						cc.call_deferred("grab_focus")
						return


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE and _current != "main":
		ProceduralSFX.play("select")
		_show("main", true)


func _start(index: int) -> void:
	GameState.current_level_index = index
	SceneTransition.change_scene("res://levels/MainGame.tscn")
