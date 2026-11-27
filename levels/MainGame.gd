# res://levels/MainGame.gd
# Главная игровая сцена: связывает симуляцию (TurnManager) с картинкой, вводом, HUD, звуком и «соком».
extends Node2D

const TS: int = GridManager.TILE_SIZE
const CARD_COLORS: Dictionary = {"RED": Color("#FF1E42"), "BLUE": Color("#2D7CFF"), "YELLOW": Color("#FFD700")}
const DIR_KEYS: Dictionary = {
	KEY_W: Vector2i(0, -1), KEY_UP: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_DOWN: Vector2i(0, 1),
	KEY_A: Vector2i(-1, 0), KEY_LEFT: Vector2i(-1, 0), KEY_D: Vector2i(1, 0), KEY_RIGHT: Vector2i(1, 0),
}
# Рабочая область карты между левой и правой колонками интерфейса (логические 1920x1080).
const AREA_CENTER: Vector2 = Vector2(960.0, 520.0)
const AREA_SIZE: Vector2 = Vector2(1250.0, 860.0)

const LINES: Dictionary = {
	"start": [["handler", "Канал чист. Я веду тебя по камерам. Не шуми."], ["handler", "Здание спит. Вопрос — надолго ли."]],
	"alarm": [["ai", "НАРУШИТЕЛЬ ОБНАРУЖЕН. ПРОТОКОЛ ПЕРЕХВАТА АКТИВЕН."], ["ai", "Я ВИЖУ ТЕБЯ, КРЫСА."], ["ai", "ВСЕ ПОСТЫ: ЦЕЛЬ В СЕКТОРЕ."], ["ai", "ТЫ ДЫШИШЬ СЛИШКОМ ГРОМКО."]],
	"alarm_help": [["handler", "Прячься! Тень, шкаф, вентиляция — что угодно!"], ["handler", "Не бегай по прямой. Сбрось хвост за углом."]],
	"alarm_off": [["handler", "Оторвался. Дыши ровно."], ["ai", "ПОТЕРЯ ЦЕЛИ. ПЕРЕЗАГРУЗКА ПОИСКА."]],
	"pickpocket": [["thief", "Мягкие руки."], ["thief", "Спасибо за карточку."], ["thief", "Не заметил — не считается."]],
	"stun": [["thief", "Спокойной ночи."], ["thief", "Полежи, отдохни."]],
	"gold": [["handler", "Ядро у тебя! Теперь к выходу. Они проснутся."]],
	"climax": [["ai", "ЯДРО ИЗВЛЕЧЕНО. ПРОТОКОЛ УСИЛЕНИЯ ВКЛЮЧЁН. ВЫХОДА НЕТ."]],
	"hit": [["thief", "Больно... щит держит."], ["ai", "ПОПАДАНИЕ. ЩИТ ПОВРЕЖДЁН."]],
	"laser": [["ai", "ЛАЗЕРНЫЙ КОНТУР ПЕРЕСЕЧЁН."]],
	"shot": [["ai", "ОГОНЬ НА ПОРАЖЕНИЕ."]],
	"chip": [["thief", "Мелочь, а приятно."]],
	"combo": [["handler", "Чистая работа! Так держать."], ["thief", "Я в ритме."]],
	"lost": [["ai", "НАРУШИТЕЛЬ ЛИКВИДИРОВАН. ПРОТОКОЛ ЗАВЕРШЁН."]],
	"cloak": [["thief", "Теперь меня нет."]],
}

var sim: TurnManager
var level_index: int = 0
var world: Node2D
var bg: NeonGridBackground
var tile_layer: TileLayer
var threat: ThreatLayer
var floor_layer: Node2D
var ent_layer: Node2D
var fx: FxManager
var dust: CPUParticles2D
var hud: HUD
var modal: PauseAndResultModal
var lighting: AlarmLightingController
var env_node: WorldEnvironment
var views: Dictionary = {}
var player_view: EntityView
var busy: bool = false
var aim_slot: int = 0
var aim_cell: Vector2i = Vector2i.ZERO
var _last_alarm: bool = false
var _last_alarm_state: int = -1
var _shake: float = 0.0
var _punch: float = 0.0
var _clock: float = 0.0
var _base_scale: float = 1.0
var _result_shown: bool = false
var _auto_mode: bool = false
var _intro_t: float = 99.0
var _intro_max: float = 40.0
var _line_idx: Dictionary = {}
var _say_cd: float = 0.0
var _slowmo_token: int = 0
var _run_actions: Array = []
var _checkpoint_warning: String = ""


# ───────────────────────── построение сцены ─────────────────────────

func _ready() -> void:
	level_index = GameState.current_level_index
	_build_scene()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var shot_path: String = ""
	var actions: String = ""
	for a in user_args:
		if a.begins_with("--level="):
			level_index = int(a.substr(8)) - 1
			GameState.current_level_index = level_index
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--actions="):
			actions = a.substr(10)
	_auto_mode = shot_path != ""
	var resume: bool = GameState.resume_requested and not _auto_mode
	GameState.resume_requested = false
	if not _load_level(not _auto_mode, resume):
		return
	ProceduralSFX.start_music()
	if _auto_mode:
		await _run_auto(actions, shot_path)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	ProceduralSFX.stop_siren()


func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	env_node = WorldEnvironment.new()
	env_node.environment = env
	add_child(env_node)

	lighting = AlarmLightingController.new()
	add_child(lighting)
	lighting.build(self)

	world = Node2D.new()
	add_child(world)
	bg = NeonGridBackground.new()
	world.add_child(bg)
	tile_layer = TileLayer.new()
	world.add_child(tile_layer)
	floor_layer = Node2D.new()
	world.add_child(floor_layer)
	threat = ThreatLayer.new()
	world.add_child(threat)
	ent_layer = Node2D.new()
	world.add_child(ent_layer)
	dust = CPUParticles2D.new()
	dust.texture = UITheme.tex("security/light_radial_glow")
	var dm := CanvasItemMaterial.new()
	dm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dust.material = dm
	dust.amount = 60
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.gravity = Vector2(0, -6)
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 10.0
	dust.direction = Vector2(0, -1)
	dust.spread = 60.0
	dust.scale_amount_min = 0.03
	dust.scale_amount_max = 0.09
	dust.color = Color(0.5, 1.4, 1.6, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 0))
	dg.add_point(0.3, Color(1, 1, 1, 1))
	dg.set_color(dg.get_point_count() - 1, Color(1, 1, 1, 0))
	dust.color_ramp = dg
	world.add_child(dust)
	fx = FxManager.new()
	world.add_child(fx)

	hud = HUD.new()
	add_child(hud)
	EventBus.hud_refresh.connect(hud.update_from)
	modal = PauseAndResultModal.new()
	add_child(modal)
	modal.action_chosen.connect(_on_modal_action)


func _load_level(show_briefing: bool, resume: bool = false) -> bool:
	ProceduralSFX.stop_siren()
	_run_actions = []
	_checkpoint_warning = ""
	if level_index < 0 or level_index >= GameState.LEVEL_FILES.size():
		modal.show_load_error("Неверный номер миссии.")
		return false
	var loaded: Dictionary = LevelLoader.read_file(GameState.LEVEL_FILES[level_index])
	if loaded.has("error"):
		sim = null
		modal.show_load_error(String(loaded["error"]))
		return false
	if resume:
		var checkpoint: Dictionary = RunCheckpoint.read()
		sim = RunCheckpoint.restore(checkpoint, level_index, loaded["data"])
		if sim != null:
			_run_actions = checkpoint["actions"].duplicate()
			show_briefing = false
		else:
			_checkpoint_warning = "Сохранение миссии повреждено или несовместимо. Миссия начата заново."
	else:
		sim = null
	if sim == null:
		sim = LevelLoader.build(loaded["data"])
	_result_shown = false
	aim_slot = 0
	threat.aim_slot = 0
	_say_cd = 0.0
	_line_idx.clear()
	for c in ent_layer.get_children():
		c.queue_free()
	for c in floor_layer.get_children():
		c.queue_free()
	views.clear()
	tile_layer.setup(sim)
	threat.setup(sim)
	bg.configure(sim.grid.width, sim.grid.height)
	_fit_world()
	dust.position = Vector2(sim.grid.width * TS * 0.5, sim.grid.height * TS * 0.5)
	dust.emission_rect_extents = Vector2(sim.grid.width * TS * 0.5, sim.grid.height * TS * 0.5)
	dust.amount = clampi(sim.grid.width * sim.grid.height / 6, 30, 90)
	_create_views()
	hud.setup(sim)
	hud.set_level(String(sim.level_data.get("title", "")))
	_last_alarm = false
	_last_alarm_state = -1
	_sync_views(false)
	_refresh_all()
	_start_intro()
	if show_briefing:
		modal.show_briefing(sim.level_data, level_index)
	else:
		_say_level_intro()
	if _checkpoint_warning != "":
		hud.flash_message(_checkpoint_warning, UITheme.AMBER)
	return true


func _start_intro() -> void:
	tile_layer.reveal = 0.0
	tile_layer.reveal_origin = sim.player.grid_pos
	_intro_max = float(sim.grid.width + sim.grid.height) + 6.0
	_intro_t = 0.0
	busy = true
	ProceduralSFX.play("whoosh", -4.0)
	var tw: Tween = create_tween()
	tw.tween_property(tile_layer, "reveal", _intro_max, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		tile_layer.reveal = 999.0
		_intro_t = 99.0
		busy = false
		for v in views.values():
			(v as EntityView).modulate.a = 1.0
			(v as EntityView).scale = Vector2.ONE
		tile_layer.queue_redraw())


func _say_level_intro() -> void:
	var intro: Array = sim.level_data.get("intro", [])
	if intro.is_empty():
		_say_line("start", true)
		return
	for l in intro:
		hud.dialogue.say(String(l[0]), String(l[1]), 3.2)


func _fit_world() -> void:
	var map := Vector2(sim.grid.width * TS, sim.grid.height * TS)
	_base_scale = minf(AREA_SIZE.x / map.x, AREA_SIZE.y / map.y)
	_base_scale = minf(_base_scale, 2.2)
	_apply_transform()


func _apply_transform() -> void:
	if sim == null:
		return
	var map := Vector2(sim.grid.width * TS, sim.grid.height * TS)
	var s: float = _base_scale * (1.0 + _punch)
	world.scale = Vector2(s, s)
	var off := Vector2(sin(_clock * 71.0), cos(_clock * 83.0)) * _shake
	world.position = AREA_CENTER - map * s * 0.5 + off


func punch(amount: float) -> void:
	_punch = minf(0.08, _punch + amount)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# Замедление времени (настоящая секунда не замедляется).
func slowmo(time_scale: float, real_seconds: float) -> void:
	_slowmo_token += 1
	var token: int = _slowmo_token
	Engine.time_scale = time_scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if token == _slowmo_token:
		Engine.time_scale = 1.0


func _make_view(texture: String, cell: Vector2i, z: int, parent: Node2D) -> EntityView:
	var v := EntityView.new()
	parent.add_child(v)
	v.setup(texture, z)
	v.place(cell, false)
	return v


func _create_views() -> void:
	for it in sim.loot:
		var tex: String = "interactables/loot_crypto_chip"
		match it.kind:
			"gold": tex = "interactables/loot_vault_gold_core"
			"keycard": tex = "interactables/item_keycards_set"
			"medkit": tex = "interactables/item_medkit_stim"
		var v: EntityView = _make_view(tex, it.grid_pos, 2, floor_layer)
		if it.kind == "gold":
			v.set_glow(Color(1.6, 1.2, 0.2, 0.7), 2.8)
			v.pulse = 0.07
			v.spin = 0.35
			v.spr.scale = Vector2(0.95, 0.95)
		elif it.kind == "chip":
			v.set_glow(Color(0.2, 1.1, 1.3, 0.5), 1.7)
			v.bob = 2.5
			v.spr.scale = Vector2(0.8, 0.8)
		views[it.id] = v
	for d in sim.doors:
		views[d.id] = _make_view("interactables/door_electronic_blue", d.grid_pos, 3, ent_layer)
	for sw in sim.switches:
		var v3: EntityView = _make_view("interactables/interact_server_terminal" if sw.kind == "terminal" else "interactables/interact_power_switch", sw.grid_pos, 3, ent_layer)
		v3.spr.scale = Vector2(0.9, 0.9)
		views[sw.id] = v3
	for l in sim.lasers:
		var v4: EntityView = _make_view("security/laser_emitter_node", l.grid_pos, 3, ent_layer)
		v4.face(l.facing, false)
		v4.set_glow(Color(1.6, 0.1, 0.2, 0.35), 1.4)
		views[l.id] = v4
	for c in sim.cameras:
		var v5: EntityView = _make_view("security/security_camera_active", c.grid_pos, 4, ent_layer)
		v5.face(c.facing, false)
		v5.set_glow(Color(1.6, 0.9, 0.1, 0.4), 1.6)
		views[c.id] = v5
	for t in sim.turrets:
		var v6: EntityView = _make_view("security/sentry_turret_sleep", t.grid_pos, 4, ent_layer)
		v6.face(t.facing, false)
		views[t.id] = v6
	for g in sim.guards:
		var v7: EntityView = _make_view("enemies/guard_standard_patrol", g.grid_pos, 5, ent_layer)
		v7.face(g.facing, false)
		var gc: Color = Color(1.6, 0.15, 0.3, 0.35)
		if g.kind == "elite":
			gc = Color(1.2, 0.2, 1.6, 0.4)
		elif g.kind == "hound":
			gc = Color(1.8, 0.8, 0.1, 0.4)
		elif g.kind == "drone":
			gc = Color(0.3, 1.6, 1.0, 0.4)
		v7.set_glow(gc, 1.8)
		views[g.id] = v7
	player_view = _make_view("player/player_idle_topdown", sim.player.grid_pos, 6, ent_layer)
	player_view.set_glow(Color(0.2, 1.0, 1.4, 0.5), 2.2)
	player_view.face(sim.player.facing, false)
	player_view.pulse = 0.02
	views["player"] = player_view


# ───────────────────────── синхронизация картинки с симуляцией ─────────────────────────

func _guard_tex(g: BaseEnemy) -> String:
	if g.is_stunned():
		return "enemies/guard_standard_stunned"
	match g.kind:
		"elite":
			return "enemies/guard_elite_overdrive" if g.state == BaseEnemy.AIState.CHASE else "enemies/guard_elite_idle"
		"hound":
			return "enemies/guard_cyber_hound"
		"drone":
			return "enemies/drone_scout_alarm" if g.state == BaseEnemy.AIState.CHASE else "enemies/drone_scout_idle"
	return "enemies/guard_standard_keycard" if g.keycard_color != "" else "enemies/guard_standard_patrol"


func _sync_views(animate: bool) -> void:
	for it in sim.loot:
		var v: EntityView = views[it.id]
		v.visible = not it.collected
	for d in sim.doors:
		var v2: EntityView = views[d.id]
		v2.set_tex("interactables/door_electronic_open" if d.is_open() else _door_tex(d.required_keycard))
	for sw in sim.switches:
		var v3: EntityView = views[sw.id]
		v3.set_tint(Color(0.6, 1.5, 0.8) if sw.on else Color(1, 1, 1))
	for l in sim.lasers:
		var v4: EntityView = views[l.id]
		var live: bool = l.enabled and l.emp_turns <= 0 and not sim.is_group_off(l.group_id)
		v4.set_tint(Color(1, 1, 1) if live else Color(0.4, 0.4, 0.5))
		v4.glow.visible = live
	for c in sim.cameras:
		var v5: EntityView = views[c.id]
		v5.face(c.facing, animate)
		var act: bool = c.is_active(sim)
		v5.set_tex("security/security_camera_active" if act else "security/security_camera_disabled")
		v5.glow.visible = act
	for t in sim.turrets:
		var v6: EntityView = views[t.id]
		v6.face(t.facing, animate)
		v6.set_tex("security/sentry_turret_active" if t.is_armed(sim) else "security/sentry_turret_sleep")
		v6.set_tint(Color(1.8, 0.5, 0.5) if t.locked else Color.WHITE)
	for g in sim.guards:
		var v7: EntityView = views[g.id]
		v7.visible = g.is_active()
		v7.place(g.grid_pos, animate, 0.12)
		if g.kind != "drone":
			v7.face(g.facing, animate)
		else:
			v7.face(g.facing, animate)
		v7.set_tex(_guard_tex(g))
		var base: float = 0.92
		if g.kind == "elite": base = 0.98
		elif g.kind == "hound": base = 0.9
		v7.spr.scale = Vector2(base, base)
		v7.set_tint(Color(0.55, 0.7, 0.8) if g.is_stunned() else Color.WHITE)
		v7.glow.visible = not g.is_stunned()
		match g.state:
			BaseEnemy.AIState.SUSPICIOUS_FREEZE: v7.set_badge("?", UITheme.AMBER)
			BaseEnemy.AIState.INVESTIGATE: v7.set_badge("?!", Color("#FF8800"))
			BaseEnemy.AIState.CHASE: v7.set_badge("!", UITheme.RED)
			BaseEnemy.AIState.RETURN: v7.set_badge("<", Color("#4FA3FF"))
			BaseEnemy.AIState.STUNNED: v7.set_badge("zZ", UITheme.CYAN)
			_: v7.set_badge("", Color.WHITE)
		if g.keycard_color != "":
			v7.key_color = CARD_COLORS.get(g.keycard_color, Color.WHITE)
		else:
			v7.key_color = Color(0, 0, 0, 0)
		v7.refresh_draw()
	var p: PlayerController = sim.player
	player_view.place(p.grid_pos, animate, 0.1)
	player_view.face(p.facing, animate)
	var ptex: String = "player/player_idle_topdown"
	var alpha: float = 1.0
	if sim.result == "lost":
		ptex = "player/player_eliminated"
	elif p.is_in_vent(sim):
		ptex = "player/player_vent_crawl"
	elif p.cloak_turns > 0:
		ptex = "player/player_cloak_active"
	elif p.hp < PlayerController.MAX_HP:
		ptex = "player/player_damaged"
	if p.is_hidden_in_closet(sim):
		alpha = 0.4
	elif p.is_in_vent(sim):
		alpha = 0.85
	player_view.set_tex(ptex)
	player_view.spr.modulate = Color(1, 1, 1, alpha)
	var alarm_now: bool = sim.alarm.is_alarm()
	if alarm_now != _last_alarm:
		_last_alarm = alarm_now
		tile_layer.queue_redraw()
		if alarm_now:
			ProceduralSFX.start_siren()
		else:
			ProceduralSFX.stop_siren()
	if sim.alarm.state != _last_alarm_state:
		_last_alarm_state = sim.alarm.state
		EventBus.alarm_state_changed.emit(sim.alarm.state)
	lighting.set_alarm(sim.alarm.state, sim.alarm.cooldown)
	bg.alarm = alarm_now


func _door_tex(color: String) -> String:
	match color:
		"RED": return "interactables/door_electronic_red"
		"YELLOW": return "interactables/door_electronic_yellow"
	return "interactables/door_electronic_blue"


func _refresh_all() -> void:
	if sim.result == "":
		threat.set_preview(sim.compute_preview())
	else:
		threat.set_preview({})
	EventBus.hud_refresh.emit(sim, int(threat.danger.get(sim.player.grid_pos, 0)))


# ───────────────────────── ввод ─────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if modal.is_open or _auto_mode or sim == null:
		return
	if event is InputEventMouseMotion and aim_slot > 0:
		aim_cell = sim.grid.world_to_grid(world.get_local_mouse_position())
		threat.aim_cell = aim_cell
		return
	if event is InputEventMouseButton and event.pressed and aim_slot > 0:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			aim_cell = sim.grid.world_to_grid(world.get_local_mouse_position())
			_confirm_aim()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_aim()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var k: InputEventKey = event
	var code: int = GameState.gameplay_key(k.physical_keycode)
	if k.echo and code in [KEY_ESCAPE, KEY_R, KEY_BACKSPACE, KEY_1, KEY_2, KEY_3, KEY_4, KEY_M, KEY_E, KEY_F, KEY_T, KEY_H]:
		return
	if code == KEY_ESCAPE:
		if aim_slot > 0:
			_cancel_aim()
		else:
			modal.show_pause()
		get_viewport().set_input_as_handled()
		return
	if code == KEY_M:
		ProceduralSFX.toggle_mute()
		return
	if code == KEY_T:
		threat.show_current = not threat.show_current
		return
	if code == KEY_H:
		hud.toggle_help()
		return
	if code == KEY_R:
		_restart()
		return
	if code == KEY_BACKSPACE:
		_undo()
		return
	if aim_slot > 0:
		if DIR_KEYS.has(code):
			aim_cell += DIR_KEYS[code]
			aim_cell = Vector2i(clampi(aim_cell.x, 0, sim.grid.width - 1), clampi(aim_cell.y, 0, sim.grid.height - 1))
			threat.aim_cell = aim_cell
			ProceduralSFX.play("click", -6.0)
		elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			_confirm_aim()
		elif code == KEY_1 or code == KEY_2:
			var slot: int = 1 if code == KEY_1 else 2
			if slot == aim_slot:
				_cancel_aim()
			else:
				_begin_aim(slot)
		get_viewport().set_input_as_handled()
		return
	if busy:
		return
	if DIR_KEYS.has(code):
		var dir: Vector2i = DIR_KEYS[code]
		if k.shift_pressed:
			_do_action({"type": "dash", "dir": dir})
		else:
			_do_action({"type": "move", "dir": dir})
	elif code == KEY_SPACE or code == KEY_Z:
		_do_action({"type": "wait"})
	elif code == KEY_E:
		_do_action({"type": "interact"})
	elif code == KEY_F:
		_do_action({"type": "takedown"})
	elif code in [KEY_1, KEY_2, KEY_3, KEY_4]:
		_use_gadget(code - KEY_1 + 1)


func _use_gadget(slot: int) -> void:
	var keys: Array = ["smoke", "decoy", "emp", "cloak"]
	if int(sim.player.gadgets[keys[slot - 1]]) <= 0:
		hud.flash_message("Этот гаджет закончился", UITheme.RED)
		ProceduralSFX.play("error")
		return
	if slot <= 2:
		_begin_aim(slot)
	else:
		_do_action({"type": "gadget", "slot": slot, "target": sim.player.grid_pos})


func _begin_aim(slot: int) -> void:
	aim_slot = slot
	aim_cell = sim.player.grid_pos + sim.player.facing * (2 if slot == 1 else 3)
	if not sim.grid.is_in_bounds(aim_cell):
		aim_cell = sim.player.grid_pos
	threat.aim_slot = slot
	threat.aim_cell = aim_cell
	var what: String = "ДЫМОВУЮ ШАШКУ (до 3 клеток)" if slot == 1 else "ШУМОВОЙ МАНОК (до 4 клеток)"
	hud.flash_message("Куда бросить %s? Стрелки/мышь — цель, Space/клик — бросок, Esc — отмена" % what, UITheme.CYAN)
	ProceduralSFX.play("click")


func _cancel_aim() -> void:
	aim_slot = 0
	threat.aim_slot = 0


func _confirm_aim() -> void:
	var slot: int = aim_slot
	var target: Vector2i = aim_cell
	var r: Dictionary = _preflight_gadget(slot, target)
	if not r["ok"]:
		hud.flash_message(String(r["msg"]), UITheme.RED)
		ProceduralSFX.play("error")
		return
	aim_slot = 0
	threat.aim_slot = 0
	ProceduralSFX.play("throw")
	_do_action({"type": "gadget", "slot": slot, "target": target})


func _preflight_gadget(slot: int, target: Vector2i) -> Dictionary:
	var maxd: int = 3 if slot == 1 else 4
	var d: int = absi(target.x - sim.player.grid_pos.x) + absi(target.y - sim.player.grid_pos.y)
	if d > maxd or d == 0 or not sim.grid.is_in_bounds(target):
		return {"ok": false, "msg": "Слишком далеко или недопустимая клетка"}
	var t: int = sim.grid.get_tile(target)
	if t == GridManager.TileType.WALL or t == GridManager.TileType.VOID or t == GridManager.TileType.SERVER:
		return {"ok": false, "msg": "Нельзя бросить в стену"}
	return {"ok": true, "msg": ""}


func _do_action(action: Dictionary) -> void:
	if busy or sim.result != "":
		return
	var acted_sim: TurnManager = sim
	var hp_before: int = sim.player.hp
	var r: Dictionary = sim.execute_player_turn(action)
	if not bool(r["ok"]):
		var msg: String = String(r["msg"])
		if msg != "":
			hud.flash_message(msg, UITheme.AMBER)
			ProceduralSFX.play("error")
			shake(2.0)
		_sync_views(true)
		return
	busy = true
	_run_actions.append(RunCheckpoint.pack_action(action))
	EventBus.turn_completed.emit(sim.turn_number)
	if sim.result == "":
		_save_checkpoint()
	if action["type"] == "gadget":
		hud.loadout.kick(int(action["slot"]))
	if String(r["msg"]) != "":
		hud.flash_message(String(r["msg"]), UITheme.CYAN)
	_sync_views(true)
	_handle_events(r["events"])
	if sim.player.hp < hp_before:
		hud.loadout.shield_hit = 1.0
	_refresh_all()
	await get_tree().create_timer(0.13).timeout
	if sim != acted_sim:
		return
	busy = false
	if sim.result != "" and not _result_shown:
		_result_shown = true
		await get_tree().create_timer(0.7, true, false, true).timeout
		if sim == acted_sim and sim.result != "":
			_show_result()


func _undo() -> void:
	if busy:
		return
	if sim.undo():
		if not _run_actions.is_empty():
			_run_actions.pop_back()
		_save_checkpoint()
		ProceduralSFX.play("undo")
		_result_shown = false
		Engine.time_scale = 1.0
		if modal.is_open:
			modal.close()
		_sync_views(false)
		_refresh_all()
		lighting.kick_glitch(0.6)
		hud.flash_message("Откат хода", UITheme.AMBER)
		hud.feed.push("откат хода", UITheme.AMBER)
	else:
		hud.flash_message("Нечего откатывать", UITheme.DIM)
		ProceduralSFX.play("error")


func _restart() -> void:
	if modal.is_open:
		modal.close()
	Engine.time_scale = 1.0
	_clear_checkpoint()
	if not _load_level(false):
		return
	ProceduralSFX.play("select")
	lighting.kick_glitch(0.8)
	hud.flash_message("Рестарт", UITheme.CYAN)


func _show_result() -> void:
	ProceduralSFX.stop_siren()
	if sim.result == "won":
		_clear_checkpoint()
		var stats: Dictionary = {
			"rank": sim.get_rating(), "turns": sim.turn_number, "par": int(sim.level_data.get("par_turns", 0)),
			"alarms": sim.alarm.times_triggered, "chips": sim.player.chips, "chips_total": sim.chips_total,
			"undos": sim.undo_count, "score": sim.player.score, "maxmult": int(sim.stats["maxmult"]),
		}
		GameState.record_result(level_index, String(stats["rank"]), sim.turn_number, sim.player.score)
		var got: Array[String] = GameState.check_victory_achievements(sim, level_index)
		stats["achievements"] = got
		EventBus.mission_accomplished.emit(stats)
		modal.show_victory(stats, GameState.has_next_level())
	elif sim.result == "lost":
		EventBus.mission_failed.emit(sim.fail_reason)
		ProceduralSFX.play("fail")
		modal.show_defeat(sim.fail_reason, sim.turn_number, sim.player.chips, sim.chips_total)


func _save_checkpoint() -> void:
	if _auto_mode or GameState.needs_profile_reset:
		return
	if RunCheckpoint.store(level_index, _run_actions, sim.undo_count) != OK:
		hud.flash_message("Не удалось сохранить ход на диск", UITheme.AMBER)


func _clear_checkpoint() -> void:
	if _auto_mode or GameState.needs_profile_reset or RunCheckpoint.read().get("level") != level_index:
		return
	if DirAccess.remove_absolute(RunCheckpoint.PATH) != OK:
		push_warning("Не удалось удалить сохранение завершённой миссии")


func _on_modal_action(action: String) -> void:
	match action:
		"start", "resume":
			modal.close()
			if action == "start":
				_say_level_intro()
		"restart":
			_restart()
		"briefing":
			modal.show_briefing(sim.level_data, level_index)
		"mute":
			ProceduralSFX.toggle_mute()
		"settings":
			modal.show_settings()
		"back_to_pause":
			GameState.save_progress()
			modal.show_pause()
		"undo":
			modal.close()
			_undo()
		"menu":
			ProceduralSFX.stop_siren()
			Engine.time_scale = 1.0
			modal.close()
			SceneTransition.change_scene("res://ui/MainMenu.tscn")
		"next":
			ProceduralSFX.stop_siren()
			Engine.time_scale = 1.0
			GameState.current_level_index = level_index + 1
			modal.close()
			SceneTransition.change_scene("res://levels/MainGame.tscn")


# ───────────────────────── события -> звук, частицы, диалоги ─────────────────────────

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TS + 24, c.y * TS + 24)


func _say_line(key: String, force: bool = false) -> void:
	var override: Dictionary = sim.level_data.get("lines", {})
	var arr: Array = override.get(key, LINES.get(key, []))
	if arr.is_empty():
		return
	if not force and _say_cd > 0.0:
		return
	var idx: int = int(_line_idx.get(key, 0))
	_line_idx[key] = idx + 1
	var l: Array = arr[idx % arr.size()]
	hud.dialogue.say(String(l[0]), String(l[1]))
	_say_cd = 3.0


func _log(text: String, color: Color = UITheme.TEXT) -> void:
	hud.feed.push(text, color, sim.turn_number)


func _handle_events(events: Array) -> void:
	var pc: Vector2 = _cell_center(sim.player.grid_pos)
	for e in events:
		match String(e["t"]):
			"step":
				ProceduralSFX.play("step", -4.0)
				var from_c: Vector2 = _cell_center(e["from"])
				fx.ring(from_c, 15.0, Color(0.3, 1.2, 1.4, 0.7), 0.5, 2.0)
				fx.burst(from_c, Color(0.4, 1.4, 1.6, 0.8), 4, 40.0, 0.4, 0.05)
			"vent_prep":
				ProceduralSFX.play("vent")
				fx.puff(_cell_center(e["pos"]), 5)
				_log("протискиваюсь в шахту...", UITheme.DIM)
			"dash":
				ProceduralSFX.play("dash")
				var a: Vector2 = _cell_center(e["from"])
				var b: Vector2 = _cell_center(e["to"])
				var rot: float = Vector2(sim.player.facing).angle()
				for i in range(4):
					fx.ghost(player_view.spr.texture, a.lerp(b, float(i) / 3.0), rot, Vector2(0.95, 0.95), Color(0.3, 1.2, 1.8, 0.7), 0.35 + 0.05 * float(i))
				fx.ring(b, 3.0 * TS, Color(1.6, 1.0, 0.2, 0.8), 0.6, 3.0)
				fx.burst(b, Color(2.0, 1.4, 0.3), 14, 150.0, 0.5, 0.1)
				punch(0.012)
			"door_open":
				ProceduralSFX.play("door")
				fx.burst(_cell_center(e["pos"]), Color(1.6, 1.4, 0.4), 18, 120.0, 0.5, 0.08)
				_log("дверь вскрыта", UITheme.CYAN)
			"pickup":
				match String(e["kind"]):
					"gold":
						ProceduralSFX.play("gold")
						hud.toast("ЯДРО ДАННЫХ УКРАДЕНО", UITheme.GOLD, true)
						var gp: Vector2 = _cell_center(e["pos"])
						fx.burst(gp, Color(2.2, 1.7, 0.3), 60, 320.0, 1.1, 0.16, 180.0, Vector2.RIGHT, 80.0)
						fx.ring(gp, 6.0 * TS, Color(2.0, 1.5, 0.3), 0.9, 4.0, true)
						fx.flash_at(gp, Color(2.0, 1.6, 0.4, 0.9), 260.0, 0.6)
						punch(0.05)
						slowmo(0.3, 0.55)
						_say_line("gold", true)
						_log("ЯДРО ДАННЫХ УКРАДЕНО", UITheme.GOLD)
					"chip":
						ProceduralSFX.play("pickup")
						fx.float_text(_cell_center(e["pos"]), "+500 " + String(e["name"]), UITheme.GOLD)
						fx.burst(_cell_center(e["pos"]), Color(2.0, 1.5, 0.3), 22, 170.0, 0.7, 0.1)
						_say_line("chip")
						_log("чип: %s" % String(e["name"]), UITheme.GOLD)
					"keycard":
						ProceduralSFX.play("pickup")
						fx.float_text(_cell_center(e["pos"]), "КЛЮЧ-КАРТА", UITheme.CYAN)
						_log("найдена ключ-карта", UITheme.CYAN)
					_:
						ProceduralSFX.play("pickup")
						fx.float_text(_cell_center(e["pos"]), "+1 ЩИТ", UITheme.GREEN)
						fx.burst(_cell_center(e["pos"]), Color(0.3, 2.0, 0.8), 20, 140.0, 0.7, 0.1)
			"pickpocket":
				ProceduralSFX.play("pickup")
				var cc: Color = CARD_COLORS.get(String(e["color"]), Color.WHITE)
				fx.float_text(_cell_center(e["pos"]), "КРАЖА: %s КАРТА" % TurnManager.card_name(String(e["color"])), cc, 20)
				fx.tracer(_cell_center(e["pos"]), pc, Color(cc.r * 2.0, cc.g * 2.0, cc.b * 2.0))
				fx.burst(pc, Color(cc.r * 2.0, cc.g * 2.0, cc.b * 2.0), 26, 170.0, 0.6, 0.1)
				_say_line("pickpocket")
				_log("украл %s карту" % TurnManager.card_name(String(e["color"])).to_lower(), cc)
			"stun":
				ProceduralSFX.play("stun")
				var sp: Vector2 = _cell_center(e["pos"])
				fx.bolt(pc, sp)
				fx.ring(sp, 1.2 * TS, Color(0.4, 1.6, 2.0), 0.5)
				fx.burst(sp, Color(0.5, 1.8, 2.4), 24, 200.0, 0.5, 0.08)
				punch(0.02)
				slowmo(0.35, 0.25)
				_say_line("stun")
				_log("охранник оглушён", UITheme.CYAN)
			"heard":
				fx.float_text(_cell_center(e["pos"]), "!?", Color("#FF8800"), 18, 20.0)
			"suspicious":
				ProceduralSFX.play("suspicious")
				_log("охранник что-то заподозрил", UITheme.AMBER)
			"spotted", "spotted_cam":
				ProceduralSFX.play("spotted")
				fx.burst(_cell_center(e["pos"]), Color(2.2, 0.3, 0.4), 16, 150.0, 0.5, 0.1)
				_log("НАС ЗАМЕТИЛИ", UITheme.RED)
			"alarm_on":
				ProceduralSFX.play("alarm_on")
				hud.toast("ТРЕВОГА!", UITheme.RED, true)
				hud.flash_message(String(e["reason"]), UITheme.RED)
				lighting.flash(Color(1, 0, 0.1), 0.25)
				lighting.kick_glitch(0.5)
				fx.ring(pc, 11.0 * TS, Color(1.8, 0.2, 0.3), 0.9, 4.0)
				fx.ring(pc, 7.0 * TS, Color(1.8, 0.3, 0.3), 0.7, 3.0)
				punch(0.045)
				shake(7.0)
				hud.pulse_panels(UITheme.RED)
				_say_line("alarm", true)
				hud.dialogue.say("handler", String((LINES["alarm_help"] as Array)[int(_line_idx.get("alarm", 1)) % 2][1]), 2.2)
				_log("ТРЕВОГА: %s" % String(e["reason"]), UITheme.RED)
			"alarm_off":
				ProceduralSFX.play("alarm_off")
				hud.toast("ТРЕВОГА СНЯТА", UITheme.CYAN)
				_say_line("alarm_off", true)
				_log("тревога снята", UITheme.GREEN)
			"laser_hit":
				ProceduralSFX.play("laser")
				fx.float_text(_cell_center(e["pos"]), "ЛАЗЕР!", UITheme.RED)
				fx.burst(_cell_center(e["pos"]), Color(2.4, 0.3, 0.4), 30, 260.0, 0.5, 0.09)
				lighting.kick_glitch(0.5)
				_say_line("laser")
			"shot":
				ProceduralSFX.play("shot")
				fx.tracer(_cell_center(e["from"]), _cell_center(e["to"]))
				fx.burst(_cell_center(e["to"]), Color(2.4, 0.4, 0.4), 30, 280.0, 0.5, 0.1)
				shake(10.0)
				punch(0.03)
				lighting.flash(Color(1, 0.1, 0.2), 0.4)
				_say_line("shot")
				_log("турель попала в нас", UITheme.RED)
			"hit":
				ProceduralSFX.play("hit")
				shake(11.0)
				punch(0.03)
				lighting.flash(Color(1, 0.05, 0.1), 0.55)
				lighting.kick_glitch(0.8)
				fx.float_text(_cell_center(e["pos"]), "-1 ЩИТ", UITheme.RED)
				fx.burst(_cell_center(e["pos"]), Color(2.4, 0.2, 0.3), 36, 300.0, 0.6, 0.12)
				hud.pulse_panels(UITheme.RED)
				_say_line("hit", true)
				_log("ПОВРЕЖДЁН ЩИТ", UITheme.RED)
			"smoke":
				ProceduralSFX.play("smoke")
				var sc: Vector2 = _cell_center(e["pos"])
				fx.ring(sc, 1.8 * TS, Color(0.7, 0.9, 1.0), 0.6)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						fx.puff(sc + Vector2(dx * TS, dy * TS), 4)
				_log("дымовая завеса 3x3", UITheme.CYAN)
			"decoy":
				ProceduralSFX.play("decoy")
				var dc: Vector2 = _cell_center(e["pos"])
				for i in range(3):
					await_ring(dc, 4.0 * TS, Color(1.7, 1.1, 0.2), 0.7, float(i) * 0.18)
				fx.burst(dc, Color(2.0, 1.4, 0.3), 20, 120.0, 0.6, 0.08)
				_log("манок: шум в радиусе 4", UITheme.AMBER)
			"emp":
				ProceduralSFX.play("emp")
				fx.ring(pc, 2.6 * TS, Color(0.3, 1.6, 2.0), 0.6, 5.0, true)
				fx.ring(pc, 4.0 * TS, Color(0.3, 1.4, 1.9), 0.9, 2.0)
				lighting.flash(Color(0.3, 0.9, 1.0), 0.3)
				lighting.kick_glitch(0.6)
				punch(0.03)
				for c in sim.cameras:
					if absi(c.grid_pos.x - sim.player.grid_pos.x) <= 2 and absi(c.grid_pos.y - sim.player.grid_pos.y) <= 2:
						fx.bolt(pc, _cell_center(c.grid_pos))
				for t in sim.turrets:
					if absi(t.grid_pos.x - sim.player.grid_pos.x) <= 2 and absi(t.grid_pos.y - sim.player.grid_pos.y) <= 2:
						fx.bolt(pc, _cell_center(t.grid_pos))
				for l in sim.lasers:
					if absi(l.grid_pos.x - sim.player.grid_pos.x) <= 2 and absi(l.grid_pos.y - sim.player.grid_pos.y) <= 2:
						fx.bolt(pc, _cell_center(l.grid_pos))
				_log("ЭМИ-импульс", UITheme.CYAN)
			"cloak":
				ProceduralSFX.play("cloak")
				fx.ring(pc, 1.6 * TS, Color(0.6, 0.4, 2.0), 0.6, 3.0)
				fx.burst(pc, Color(0.8, 0.5, 2.2), 24, 120.0, 0.7, 0.08)
				_say_line("cloak")
				_log("оптический плащ: 2 хода", Color("#9D7BFF"))
			"switch":
				ProceduralSFX.play("switch")
				fx.burst(_cell_center(e["pos"]), Color(0.5, 2.0, 1.0), 18, 120.0, 0.5, 0.08)
				var txt: String = String(e["text"]) if bool(e["on"]) else "Питание восстановлено"
				hud.flash_message(txt, UITheme.GREEN if bool(e["on"]) else UITheme.AMBER)
				_log(txt, UITheme.GREEN)
			"climax":
				ProceduralSFX.play("climax")
				hud.toast("ПРОТОКОЛ УСИЛЕНИЯ БЕЗОПАСНОСТИ", UITheme.RED, true)
				lighting.flash(Color(1, 0.1, 0.1), 0.35)
				lighting.kick_glitch(0.6)
				fx.ring(pc, 14.0 * TS, Color(1.8, 0.2, 0.3), 1.2, 5.0)
				shake(8.0)
				_say_line("climax", true)
				_log("ПРОТОКОЛ УСИЛЕНИЯ БЕЗОПАСНОСТИ", UITheme.RED)
			"spawn_guard":
				ProceduralSFX.play("spawn")
				var spc: Vector2 = _cell_center(e["pos"])
				fx.ring(spc, 2.0 * TS, Color(1.6, 0.3, 2.0), 0.8, 4.0, true)
				fx.burst(spc, Color(1.8, 0.4, 2.2), 30, 200.0, 0.8, 0.12)
				_log("проснулся резервный страж!", UITheme.RED)
			"closet_exposed":
				hud.flash_message("Вас заметили при входе в шкаф — укрытие не работает!", UITheme.RED)
			"guard_move":
				var gv: BaseEnemy = null
				for g in sim.guards:
					if g.id == String(e["id"]):
						gv = g
				if gv != null and gv.state == BaseEnemy.AIState.CHASE and views.has(gv.id):
					var v: EntityView = views[gv.id]
					fx.ghost(v.spr.texture, _cell_center(e["from"]), v.spr.rotation, v.spr.scale, Color(2.0, 0.2, 0.3, 0.55), 0.45)
			"style":
				ProceduralSFX.play("combo", -2.0, 1.0 + 0.12 * float(int(e["mult"])))
				fx.float_text(pc + Vector2(0, -14), "%s +%d" % [String(e["text"]), int(e["pts"])], Color(2.0, 1.5, 0.3), 18, 52.0)
				hud.pulse_panels(UITheme.AMBER)
				_log("%s  +%d (x%d)" % [String(e["text"]), int(e["pts"]), int(e["mult"])], UITheme.AMBER)
				if int(e["mult"]) >= 3:
					_say_line("combo")
				if int(e["mult"]) >= 4 and GameState.unlock("showman"):
					_announce_achievement("showman")
			"won":
				ProceduralSFX.play("win")
				fx.burst(pc, Color(0.4, 2.0, 1.2), 80, 380.0, 1.4, 0.16, 180.0, Vector2.RIGHT, 100.0)
				fx.ring(pc, 9.0 * TS, Color(0.4, 2.0, 1.2), 1.0, 4.0, true)
				punch(0.05)
				slowmo(0.35, 0.5)
			"lost":
				lighting.kick_glitch(0.8)
				lighting.flash(Color(1, 1, 1), 0.5)
				fx.burst(pc, Color(0.5, 1.8, 2.2), 70, 300.0, 1.2, 0.14, 180.0, Vector2.RIGHT, 80.0)
				fx.ring(pc, 6.0 * TS, Color(0.5, 1.8, 2.2), 1.0, 4.0)
				shake(14.0)
				slowmo(0.2, 0.9)
				_say_line("lost", true)
				_log("АГЕНТ ЛИКВИДИРОВАН", UITheme.RED)


# Кольцо с задержкой.
func await_ring(pos: Vector2, radius: float, color: Color, dur: float, delay: float) -> void:
	if delay <= 0.0:
		fx.ring(pos, radius, color, dur, 3.0)
		return
	var t: SceneTreeTimer = get_tree().create_timer(delay)
	t.timeout.connect(func() -> void: fx.ring(pos, radius, color, dur, 3.0))


func _announce_achievement(id: String) -> void:
	var info: Array = GameState.ACHIEVEMENTS[id]
	ProceduralSFX.play("achieve")
	hud.toast("ДОСТИЖЕНИЕ: %s" % String(info[0]), UITheme.GOLD)
	_log("достижение: %s" % String(info[0]), UITheme.GOLD)


# ───────────────────────── процесс ─────────────────────────

func _process(delta: float) -> void:
	_clock += delta
	_say_cd = maxf(0.0, _say_cd - delta)
	_punch = lerpf(_punch, 0.0, minf(1.0, delta * 9.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
	_apply_transform()
	if sim != null:
		var target_tint: Color = Color.WHITE
		if sim.alarm.is_alarm():
			var k: float = 0.5 + 0.5 * sin(_clock * 7.0)
			target_tint = Color(1.0, 0.62 + 0.2 * (1.0 - k), 0.66 + 0.2 * (1.0 - k))
		tile_layer.modulate = tile_layer.modulate.lerp(target_tint, minf(1.0, delta * 8.0))
		if tile_layer.reveal < 900.0:
			tile_layer.queue_redraw()
			for id in views:
				var v: EntityView = views[id]
				var cellp: Vector2i = sim.player.grid_pos if id == "player" else v.cell
				var k2: float = clampf((tile_layer.reveal - Vector2(v.cell - tile_layer.reveal_origin).length() - 1.0) / 3.0, 0.0, 1.0)
				v.modulate.a = k2
				v.scale = Vector2.ONE * (0.3 + 0.7 * k2)
				if cellp == Vector2i(-1, -1):
					pass
			threat.modulate.a = clampf(tile_layer.reveal / _intro_max * 1.4 - 0.4, 0.0, 1.0)
		else:
			threat.modulate.a = 1.0


# ───────────────────────── автоматический режим (скриншоты, проверки) ─────────────────────────

func _run_auto(actions: String, shot_path: String) -> void:
	var solver_script: GDScript = load("res://tests/solver.gd") as GDScript
	var wait_s: float = 0.9
	for tok in actions.split(" ", false):
		if tok == "BRIEF":
			modal.show_briefing(sim.level_data, level_index)
			wait_s = 3.5
			continue
		if tok == "ALARM":
			sim.events = []
			sim.trigger_alarm(sim.player.grid_pos, "Тестовая тревога")
			_handle_events(sim.events)
			_sync_views(false)
			wait_s = 0.7
			continue
		if tok == "LOSE":
			sim.player.hp = 0
			sim.result = "lost"
			sim.fail_reason = "Агент ликвидирован"
			sim.events = [{"t": "lost", "text": "x"}]
			_handle_events(sim.events)
			break
		if tok == "PAUSE":
			modal.show_pause()
			continue
		if tok == "DIALOG":
			hud.dialogue.say("ai", "ТЫ ДЫШИШЬ СЛИШКОМ ГРОМКО.", 5.0)
			wait_s = 2.2
			continue
		var a: Dictionary = solver_script.str_to_action(tok)
		var r: Dictionary = sim.execute_player_turn(a)
		if not bool(r["ok"]):
			print("авто: действие %s не прошло: %s" % [tok, r["msg"]])
		else:
			_handle_events(r["events"])
		if sim.result != "":
			break
	_sync_views(false)
	_refresh_all()
	if sim.result != "":
		_show_result()
	await get_tree().create_timer(wait_s, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("glitch=", lighting._glitch, " alarm_amt=", lighting._alarm_amt, " ts=", Engine.time_scale)
	print("скриншот сохранён: ", shot_path, "  результат=", sim.result, "  ход=", sim.turn_number)
	get_tree().quit()
