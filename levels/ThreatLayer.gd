# res://levels/ThreatLayer.gd
# Слой угроз: конусы зрения (красная/жёлтая зоны), лазерные лучи, лучи турелей, дым,
# тактическое превью соседних клеток и режим прицеливания гаджета.
# Яркие зоны — это ЧТО СРАБОТАЕТ В СЛЕДУЮЩЕМ ТАКТЕ (после хода охраны, камер, лазеров);
# тонкие рамки — где конусы стоят сейчас.
class_name ThreatLayer
extends Node2D

const TS: int = GridManager.TILE_SIZE
const RED: Color = Color(1.0, 0.0, 0.24)
const YEL: Color = Color(1.0, 0.72, 0.0)

var sim: TurnManager
var preview: Dictionary = {}
var danger: Dictionary = {}          # Vector2i -> 2 (красная) / 1 (жёлтая)
var show_current: bool = true
var aim_slot: int = 0
var aim_cell: Vector2i = Vector2i.ZERO
var beam_cache: Dictionary = {}      # laser.id -> Array[Vector2i]
var _t: float = 0.0
var _smoke_tex: Texture2D


func setup(s: TurnManager) -> void:
	sim = s
	_smoke_tex = UITheme.tex("gadgets/vfx_smoke_cloud_tile")


func set_preview(p: Dictionary) -> void:
	preview = p
	danger.clear()
	for id in p.get("guards", {}):
		var d: Dictionary = p["guards"][id]
		_mark(d["yellow"], 1)
		_mark(d["red"], 2)
	for id in p.get("cams", {}):
		var d2: Dictionary = p["cams"][id]
		_mark(d2["yellow"], 1)
		_mark(d2["red"], 2)
	for c in p.get("lasers", {}):
		danger[c] = 2
	for id in p.get("turrets", {}):
		var d3: Dictionary = p["turrets"][id]
		_mark(d3["ray"], 2 if d3["locked"] else 1)
	beam_cache.clear()
	for l in sim.lasers:
		beam_cache[l.id] = l.beam_cells(sim.grid)
	queue_redraw()


func _mark(cells: Array, level: int) -> void:
	for c in cells:
		if int(danger.get(c, 0)) < level:
			danger[c] = level


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _cell_rect(c: Vector2i, inset: float = 0.0) -> Rect2:
	return Rect2(c.x * TS + inset, c.y * TS + inset, TS - inset * 2.0, TS - inset * 2.0)


func _draw_zone(cells: Array, origin: Vector2i, rng: float, base: Color, alpha: float) -> void:
	var pulse: float = 0.85 + 0.15 * sin(_t * 4.0)
	for c in cells:
		var d: float = Vector2(c - origin).length()
		var a: float = alpha * (1.0 - 0.45 * clampf(d / maxf(rng, 1.0), 0.0, 1.0)) * pulse
		var col := Color(base.r * 1.4, base.g * 1.4, base.b * 1.4, a)
		draw_rect(_cell_rect(c, 1.0), col)
		draw_rect(_cell_rect(c, 1.0), Color(base.r, base.g, base.b, minf(1.0, a * 2.2)), false, 1.0)


func _draw_outline(cells: Array, base: Color) -> void:
	for c in cells:
		draw_rect(_cell_rect(c, 3.0), Color(base.r, base.g, base.b, 0.28), false, 1.0)


func _draw() -> void:
	if sim == null:
		return
	# медленная сканирующая полоса по уровню
	var map_h: float = float(sim.grid.height * TS)
	var map_w: float = float(sim.grid.width * TS)
	var sy: float = fmod(_t * 55.0, map_h + 200.0) - 100.0
	for i in range(8):
		var yy: float = sy - float(i) * 3.0
		if yy > 0.0 and yy < map_h:
			draw_line(Vector2(0, yy), Vector2(map_w, yy), Color(0.3, 1.2, 1.4, 0.07 * (1.0 - float(i) / 8.0)), 2.0)
	# дым
	for c in sim.grid.smoke_cells:
		var left: int = int(sim.grid.smoke_cells[c])
		var a: float = 0.55 + 0.1 * sin(_t * 2.0 + c.x * 1.7 + c.y)
		draw_texture_rect(_smoke_tex, _cell_rect(c), false, Color(0.75, 0.9, 1.0, a))
		draw_string(UITheme.font(true), Vector2(c.x * TS + 36, c.y * TS + 12), str(left), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 1, 1, 0.9))
	# текущие конусы — тонкие рамки
	if show_current:
		for g in sim.guards:
			if g.is_active():
				_draw_outline(g.yellow_cells, YEL)
				_draw_outline(g.red_cells, RED)
		for c in sim.cameras:
			_draw_outline(c.yellow_cells, YEL)
			_draw_outline(c.red_cells, RED)
	# будущие конусы — яркая заливка
	for g in sim.guards:
		if not g.is_active() or not preview.get("guards", {}).has(g.id):
			continue
		var d: Dictionary = preview["guards"][g.id]
		if g.is_stunned() and int(d["state"]) == BaseEnemy.AIState.STUNNED:
			continue
		_draw_zone(d["yellow"], d["pos"], float(g.view_range()) + 1.0, YEL, 0.15)
		_draw_zone(d["red"], d["pos"], float(g.view_range()), RED, 0.22)
		if d["pos"] != g.grid_pos:
			var a: Vector2 = Vector2(g.grid_pos * TS) + Vector2(24, 24)
			var b: Vector2 = Vector2((d["pos"] as Vector2i) * TS) + Vector2(24, 24)
			draw_line(a, b, Color(1, 0.25, 0.35, 0.55), 2.0)
			draw_arc(b, 8.0, 0.0, TAU, 20, Color(1, 0.3, 0.4, 0.8), 2.0)
	for c in sim.cameras:
		if not preview.get("cams", {}).has(c.id):
			continue
		var cd: Dictionary = preview["cams"][c.id]
		_draw_zone(cd["yellow"], c.grid_pos, float(c.view_range(sim)) + 1.0, YEL, 0.12)
		_draw_zone(cd["red"], c.grid_pos, float(c.view_range(sim)), RED, 0.20)
	# лазеры
	for l in sim.lasers:
		var cells: Array = beam_cache.get(l.id, [])
		if cells.is_empty():
			continue
		var on_next: bool = preview.get("lasers", {}).has(cells[0])
		var start: Vector2 = Vector2(cells[0] * TS) + Vector2(24, 24) - Vector2(l.facing) * 24.0
		var end: Vector2 = Vector2(cells[cells.size() - 1] * TS) + Vector2(24, 24) + Vector2(l.facing) * 24.0
		var active_now: bool = sim.laser_cells.has(cells[0])
		if on_next:
			var flick: float = 0.85 + 0.15 * sin(_t * 30.0)
			draw_line(start, end, Color(2.2, 0.1, 0.25, 0.5 * flick), 9.0)
			draw_line(start, end, Color(2.5, 2.2, 2.2, 1.0), 2.5)
		elif l.enabled and l.emp_turns <= 0 and not sim.is_group_off(l.group_id):
			_dashed(start, end, Color(1.4, 0.2, 0.3, 0.55), 1.6, 6.0)
		else:
			_dashed(start, end, Color(0.4, 0.45, 0.55, 0.3), 1.2, 4.0)
		if active_now and not on_next:
			draw_line(start, end, Color(1.5, 0.1, 0.2, 0.2), 4.0)
	# турели
	for t in sim.turrets:
		if not preview.get("turrets", {}).has(t.id):
			continue
		var td: Dictionary = preview["turrets"][t.id]
		var ray: Array = td["ray"]
		if ray.is_empty():
			continue
		var s: Vector2 = Vector2(t.grid_pos * TS) + Vector2(24, 24)
		var e: Vector2 = Vector2((ray[ray.size() - 1] as Vector2i) * TS) + Vector2(24, 24) + Vector2(td["facing"]) * 20.0
		if td["locked"]:
			draw_line(s, e, Color(2.4, 0.1, 0.2, 0.9), 3.0)
			var pc: Vector2 = Vector2(sim.player.grid_pos * TS) + Vector2(24, 24)
			draw_arc(pc, 20.0 + 3.0 * sin(_t * 14.0), 0.0, TAU, 28, Color(2.4, 0.2, 0.3), 2.5)
		else:
			_dashed(s, e, Color(1.5, 0.8, 0.1, 0.6), 2.0, 8.0)
	# превью соседних клеток
	if sim.result == "" and aim_slot == 0:
		for d in GridManager.DIRS:
			var c: Vector2i = sim.player.grid_pos + d
			if not sim.grid.is_walkable_for_player(c, sim.player.keycards):
				continue
			if sim.guard_at(c) != null:
				continue
			var ctr: Vector2 = Vector2(c * TS) + Vector2(24, 24)
			var dg: int = int(danger.get(c, 0))
			if dg == 2:
				_warn_triangle(ctr, Color(1.8, 0.2, 0.3))
			elif dg == 1:
				draw_circle(ctr, 4.0, Color(1.6, 1.1, 0.1, 0.9))
			else:
				draw_circle(ctr, 3.0, Color(0.2, 1.2, 1.4, 0.55))
	# прицеливание
	if aim_slot > 0:
		var maxd: int = 3 if aim_slot == 1 else 4
		var pp: Vector2i = sim.player.grid_pos
		for dy in range(-maxd, maxd + 1):
			for dx in range(-maxd, maxd + 1):
				if absi(dx) + absi(dy) > maxd or (dx == 0 and dy == 0):
					continue
				var c2: Vector2i = pp + Vector2i(dx, dy)
				if sim.grid.is_in_bounds(c2) and sim.grid.get_tile(c2) not in [GridManager.TileType.WALL, GridManager.TileType.VOID, GridManager.TileType.SERVER]:
					draw_rect(_cell_rect(c2, 4.0), Color(0.2, 0.9, 1.0, 0.10))
					draw_rect(_cell_rect(c2, 4.0), Color(0.2, 0.9, 1.0, 0.35), false, 1.0)
		var ok: bool = absi(aim_cell.x - pp.x) + absi(aim_cell.y - pp.y) <= maxd and aim_cell != pp
		var col: Color = Color(0.3, 1.8, 1.9) if ok else Color(1.8, 0.3, 0.3)
		if aim_slot == 1:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					draw_rect(_cell_rect(aim_cell + Vector2i(dx, dy), 5.0), Color(col.r, col.g, col.b, 0.2))
		else:
			draw_arc(Vector2(aim_cell * TS) + Vector2(24, 24), 4.0 * TS, 0, TAU, 48, Color(col.r, col.g, col.b, 0.25), 1.5)
		draw_rect(_cell_rect(aim_cell, 2.0), col, false, 3.0)
		var cc: Vector2 = Vector2(aim_cell * TS) + Vector2(24, 24)
		draw_line(cc + Vector2(-10, 0), cc + Vector2(10, 0), col, 2.0)
		draw_line(cc + Vector2(0, -10), cc + Vector2(0, 10), col, 2.0)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float, seg: float) -> void:
	var dist: float = a.distance_to(b)
	var dir: Vector2 = (b - a).normalized()
	var off: float = fmod(_t * 20.0, seg * 2.0)
	var d: float = -off
	while d < dist:
		var s: float = maxf(d, 0.0)
		var e: float = minf(d + seg, dist)
		if e > s:
			draw_line(a + dir * s, a + dir * e, col, w)
		d += seg * 2.0


func _warn_triangle(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 6), c + Vector2(-8, 6)])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85))
	draw_line(c + Vector2(0, -3), c + Vector2(0, 1), Color.WHITE, 2.0)
	draw_circle(c + Vector2(0, 4), 1.0, Color.WHITE)
