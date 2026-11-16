# res://ui/Minimap.gd
# Тактический радар: стены, двери, охрана, камеры, конусы зрения, лазеры, игрок. Живой, с развёрткой.
class_name Minimap
extends Control

var sim: TurnManager
var _t: float = 0.0
const CARD: Dictionary = {"RED": Color("#FF1E42"), "BLUE": Color("#2D7CFF"), "YELLOW": Color("#FFD700")}


func setup(s: TurnManager) -> void:
	sim = s


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var g: GridManager = sim.grid
	var pad: float = 10.0
	var cs: float = minf((size.x - pad * 2.0) / float(g.width), (size.y - pad * 2.0 - 14.0) / float(g.height))
	var ox: float = (size.x - cs * g.width) * 0.5
	var oy: float = 14.0 + (size.y - 14.0 - cs * g.height) * 0.5
	draw_rect(Rect2(ox - 2, oy - 2, cs * g.width + 4, cs * g.height + 4), Color(0.0, 0.03, 0.05, 0.9))
	for y in range(g.height):
		for x in range(g.width):
			var p := Vector2i(x, y)
			var t: int = g.get_tile(p)
			var r := Rect2(ox + x * cs, oy + y * cs, cs + 0.5, cs + 0.5)
			match t:
				GridManager.TileType.VOID:
					pass
				GridManager.TileType.WALL, GridManager.TileType.SERVER:
					draw_rect(r, Color(0.1, 0.32, 0.42, 0.85))
				GridManager.TileType.GLASS_WALL:
					draw_rect(r, Color(0.25, 0.7, 0.9, 0.6))
				GridManager.TileType.VENT:
					draw_rect(r, Color(0.2, 0.3, 0.5, 0.9))
				GridManager.TileType.CLOSET:
					draw_rect(r, Color(0.3, 0.2, 0.5, 0.9))
				GridManager.TileType.DOOR_CLOSED:
					var d: ElectronicDoor = g.doors.get(p)
					var col: Color = CARD.get(d.required_keycard, Color(0.5, 0.6, 0.8)) if d != null else Color.WHITE
					if d != null and d.is_open():
						col = col.darkened(0.6)
					draw_rect(r, col)
				GridManager.TileType.EXTRACTION:
					draw_rect(r, Color(0.1, 0.9, 0.5, 0.7))
				_:
					draw_rect(r, Color(0.045, 0.09, 0.14, 0.95))
	# конусы
	for e in sim.guards:
		if e.is_active() and not e.is_stunned():
			for c in e.red_cells:
				draw_rect(Rect2(ox + c.x * cs, oy + c.y * cs, cs, cs), Color(1.0, 0.1, 0.2, 0.35))
			for c in e.yellow_cells:
				draw_rect(Rect2(ox + c.x * cs, oy + c.y * cs, cs, cs), Color(1.0, 0.7, 0.0, 0.2))
	for cam in sim.cameras:
		for c in cam.red_cells:
			draw_rect(Rect2(ox + c.x * cs, oy + c.y * cs, cs, cs), Color(1.0, 0.1, 0.2, 0.3))
	for c in sim.laser_cells:
		draw_rect(Rect2(ox + c.x * cs, oy + c.y * cs, cs, cs), Color(1.6, 0.1, 0.2, 0.8))
	for c in sim.grid.smoke_cells:
		draw_rect(Rect2(ox + c.x * cs, oy + c.y * cs, cs, cs), Color(0.8, 0.9, 1.0, 0.45))
	# лут
	var blink: float = 0.5 + 0.5 * sin(_t * 6.0)
	for it in sim.loot:
		if it.collected:
			continue
		var cc := Vector2(ox + (it.grid_pos.x + 0.5) * cs, oy + (it.grid_pos.y + 0.5) * cs)
		if it.kind == "gold":
			draw_circle(cc, cs * (0.8 + 0.3 * blink), Color(1.8, 1.4, 0.2, 0.9))
		else:
			draw_circle(cc, cs * 0.4, Color(0.3, 1.2, 1.4, 0.9))
	# охрана и камеры
	for e in sim.guards:
		if not e.is_active():
			continue
		var gc := Vector2(ox + (e.grid_pos.x + 0.5) * cs, oy + (e.grid_pos.y + 0.5) * cs)
		var col2: Color = Color(1.8, 0.2, 0.3)
		if e.kind == "elite":
			col2 = Color(1.5, 0.3, 1.9)
		elif e.kind == "hound":
			col2 = Color(2.0, 0.9, 0.2)
		elif e.kind == "drone":
			col2 = Color(0.4, 1.8, 0.8)
		if e.is_stunned():
			col2 = Color(0.4, 0.7, 0.9)
		draw_circle(gc, cs * 0.55, col2)
		draw_line(gc, gc + Vector2(e.facing) * cs * 1.1, col2, 1.5)
	for cam in sim.cameras:
		var cp := Vector2(ox + (cam.grid_pos.x + 0.5) * cs, oy + (cam.grid_pos.y + 0.5) * cs)
		draw_rect(Rect2(cp - Vector2(cs * 0.5, cs * 0.5), Vector2(cs, cs)), Color(1.8, 1.0, 0.1))
	for tur in sim.turrets:
		var tp := Vector2(ox + (tur.grid_pos.x + 0.5) * cs, oy + (tur.grid_pos.y + 0.5) * cs)
		draw_circle(tp, cs * 0.55, Color(1.8, 0.5, 0.2) if tur.is_armed(sim) else Color(0.5, 0.5, 0.55))
	# игрок
	var pp := Vector2(ox + (sim.player.grid_pos.x + 0.5) * cs, oy + (sim.player.grid_pos.y + 0.5) * cs)
	draw_arc(pp, cs * (1.0 + 0.8 * blink), 0.0, TAU, 20, Color(0.3, 1.6, 1.9, 0.8 - 0.5 * blink), 1.5)
	draw_rect(Rect2(pp - Vector2(cs * 0.6, cs * 0.6), Vector2(cs * 1.2, cs * 1.2)), Color(0.5, 2.0, 2.2))
	# радарная развёртка
	var sweep: float = fmod(_t * 0.35, 1.0)
	var sx: float = ox + sweep * cs * g.width
	draw_line(Vector2(sx, oy), Vector2(sx, oy + cs * g.height), Color(0.2, 1.2, 1.4, 0.35), 2.0)
	draw_string(UITheme.font(true), Vector2(4, 11), "ТАКТИЧЕСКИЙ РАДАР", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.9, 1.0, 0.9))
