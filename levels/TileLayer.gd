# res://levels/TileLayer.gd
# Статичный слой тайлов (пол, стены с неоновым кантом, стекло, вентиляция, шкафы, пьедестал, эвакуация).
class_name TileLayer
extends Node2D

var sim: TurnManager
var _t: Dictionary = {}
var reveal: float = 999.0          # радиус «проявления» уровня в клетках
var reveal_origin: Vector2i = Vector2i.ZERO
var _a: float = 1.0
const TS: int = GridManager.TILE_SIZE
const FLOOR_TINT: Color = Color(2.1, 2.2, 2.4)


func setup(s: TurnManager) -> void:
	sim = s
	for n in ["tile_floor_cyber", "tile_wall_solid", "tile_wall_glass", "tile_vent_shaft", "tile_hiding_closet",
			"tile_extraction_pad", "tile_extraction_locked", "tile_vault_pedestal", "tile_server_rack",
			"tile_corridor_hazard", "tile_wall_corner"]:
		_t[n] = UITheme.tex("tiles/%s" % n)
	queue_redraw()


func _is_open(p: Vector2i) -> bool:
	var tt: int = sim.grid.get_tile(p)
	return tt != GridManager.TileType.WALL and tt != GridManager.TileType.VOID and tt != GridManager.TileType.SERVER \
		and sim.grid.is_in_bounds(p)


func _near_open(p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and _is_open(p + Vector2i(dx, dy)):
				return true
	return false


func _dt(tex: Texture2D, r: Rect2, _tile: bool, col: Color = Color.WHITE) -> void:
	draw_texture_rect(tex, r, false, Color(col.r, col.g, col.b, col.a * _a))


func _draw() -> void:
	if sim == null:
		return
	var g: GridManager = sim.grid
	var alarm: bool = sim.alarm.is_alarm()
	for y in range(g.height):
		for x in range(g.width):
			var p := Vector2i(x, y)
			var r := Rect2(x * TS, y * TS, TS, TS)
			var tt: int = g.get_tile(p)
			_a = clampf((reveal - Vector2(p - reveal_origin).length()) / 3.0, 0.0, 1.0)
			if _a <= 0.0:
				continue
			match tt:
				GridManager.TileType.VOID:
					pass
				GridManager.TileType.WALL:
					if _near_open(p):
						_dt(_t["tile_wall_solid"], r, false, Color(0.62, 0.72, 0.8))
				GridManager.TileType.SERVER:
					_dt(_t["tile_floor_cyber"], r, false, FLOOR_TINT)
					_dt(_t["tile_server_rack"], r, false)
				GridManager.TileType.GLASS_WALL:
					_dt(_t["tile_floor_cyber"], r, false, FLOOR_TINT)
					var horiz: bool = g.get_tile(p + Vector2i(-1, 0)) in [GridManager.TileType.WALL, GridManager.TileType.GLASS_WALL] \
						and g.get_tile(p + Vector2i(1, 0)) in [GridManager.TileType.WALL, GridManager.TileType.GLASS_WALL]
					if horiz:
						_dt(_t["tile_wall_glass"], r, false, Color(1.1, 1.1, 1.2))
					else:
						draw_set_transform(r.get_center(), PI * 0.5, Vector2.ONE)
						_dt(_t["tile_wall_glass"], Rect2(-TS * 0.5, -TS * 0.5, TS, TS), false, Color(1.1, 1.1, 1.2))
						draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				GridManager.TileType.VENT:
					_dt(_t["tile_vent_shaft"], r, false)
				GridManager.TileType.CLOSET:
					_dt(_t["tile_floor_cyber"], r, false, FLOOR_TINT)
					_dt(_t["tile_hiding_closet"], r, false)
				GridManager.TileType.EXTRACTION:
					_dt(_t["tile_extraction_locked" if alarm else "tile_extraction_pad"], r, false, Color(1.15, 1.15, 1.15))
				GridManager.TileType.VAULT_FLOOR:
					_dt(_t["tile_floor_cyber"], r, false, FLOOR_TINT)
					_dt(_t["tile_vault_pedestal"], r, false, Color(1.2, 1.15, 1.0))
				GridManager.TileType.HAZARD:
					_dt(_t["tile_corridor_hazard"], r, false, Color(0.85, 0.85, 0.85))
				_:
					_dt(_t["tile_floor_cyber"], r, false, FLOOR_TINT)
