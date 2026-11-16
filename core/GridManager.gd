# res://core/GridManager.gd
# Дискретная матрица уровня + AStarGrid2D. Вся логика идёт по Vector2i, никаких хитбоксов.
class_name GridManager
extends RefCounted

const TILE_SIZE: int = 48

enum TileType {
	VOID = 0,
	FLOOR = 1,
	WALL = 2,
	GLASS_WALL = 3,
	VENT = 4,
	CLOSET = 5,
	DOOR_CLOSED = 6,
	EXTRACTION = 7,
	VAULT_FLOOR = 8,
	SERVER = 9,
	HAZARD = 10,
}

const CHAR_TO_TILE: Dictionary = {
	" ": TileType.VOID, ".": TileType.FLOOR, "#": TileType.WALL, "=": TileType.GLASS_WALL,
	"V": TileType.VENT, "C": TileType.CLOSET, "D": TileType.DOOR_CLOSED, "E": TileType.EXTRACTION,
	"G": TileType.VAULT_FLOOR, "S": TileType.SERVER, "H": TileType.HAZARD,
}

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var width: int = 24
var height: int = 14
var tile_matrix: Array = []                # [y][x] -> TileType
var smoke_cells: Dictionary = {}           # Vector2i -> оставшиеся ходы
var doors: Dictionary = {}                 # Vector2i -> ElectronicDoor
var guard_cells: Dictionary = {}           # Vector2i -> true (где сейчас стоят охранники)
var solid_entities: Dictionary = {}        # Vector2i -> true (рубильники, турели: непроходимы)
var astar_enemy: AStarGrid2D


func init_grid(w: int, h: int) -> void:
	width = w
	height = h
	tile_matrix.clear()
	smoke_cells.clear()
	doors.clear()
	guard_cells.clear()
	solid_entities.clear()
	for y in range(height):
		var row: Array = []
		row.resize(width)
		row.fill(TileType.VOID)
		tile_matrix.append(row)
	_setup_astar()


func load_layout(layout: Array) -> void:
	var h: int = layout.size()
	var w: int = 0
	for line in layout:
		w = maxi(w, String(line).length())
	init_grid(w, h)
	for y in range(h):
		var line: String = String(layout[y])
		for x in range(line.length()):
			var ch: String = line[x]
			set_tile(Vector2i(x, y), int(CHAR_TO_TILE.get(ch, TileType.FLOOR)))
	rebuild_navigation_solids()


func _setup_astar() -> void:
	astar_enemy = AStarGrid2D.new()
	astar_enemy.region = Rect2i(0, 0, width, height)
	astar_enemy.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_enemy.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_enemy.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_enemy.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_enemy.update()


func rebuild_navigation_solids() -> void:
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			astar_enemy.set_point_solid(pos, not is_walkable_for_ai(pos))


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func get_tile(pos: Vector2i) -> int:
	if not is_in_bounds(pos):
		return TileType.WALL
	return tile_matrix[pos.y][pos.x]


func set_tile(pos: Vector2i, t: int) -> void:
	if is_in_bounds(pos):
		tile_matrix[pos.y][pos.x] = t


func is_walkable_for_ai(pos: Vector2i) -> bool:
	var t: int = get_tile(pos)
	if solid_entities.has(pos):
		return false
	return t == TileType.FLOOR or t == TileType.DOOR_CLOSED or t == TileType.EXTRACTION \
		or t == TileType.VAULT_FLOOR or t == TileType.HAZARD


func is_terrain_open_for_player(pos: Vector2i) -> bool:
	var t: int = get_tile(pos)
	return t != TileType.VOID and t != TileType.WALL and t != TileType.GLASS_WALL and t != TileType.SERVER


func is_walkable_for_player(pos: Vector2i, player_keycards: Array) -> bool:
	if not is_in_bounds(pos) or solid_entities.has(pos):
		return false
	if not is_terrain_open_for_player(pos):
		return false
	if get_tile(pos) == TileType.DOOR_CLOSED:
		var d: ElectronicDoor = doors.get(pos)
		return d != null and d.can_player_unlock(player_keycards)
	return true


func door_is_open(pos: Vector2i) -> bool:
	var d: ElectronicDoor = doors.get(pos)
	if d == null:
		return false
	return d.is_open() or guard_cells.has(pos)


func blocks_vision(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return true
	if smoke_cells.has(pos):
		return true
	var t: int = get_tile(pos)
	if t == TileType.DOOR_CLOSED:
		return not door_is_open(pos)
	return t == TileType.VOID or t == TileType.WALL or t == TileType.VENT \
		or t == TileType.CLOSET or t == TileType.SERVER


# Лазер проходит сквозь стекло, но его останавливают стены, закрытые двери, шкафы, дым.
func blocks_beam(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return true
	if smoke_cells.has(pos):
		return true
	var t: int = get_tile(pos)
	if t == TileType.DOOR_CLOSED:
		return not door_is_open(pos)
	return t == TileType.VOID or t == TileType.WALL or t == TileType.SERVER \
		or t == TileType.VENT or t == TileType.CLOSET


func blocks_sound(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return true
	var t: int = get_tile(pos)
	if t == TileType.DOOR_CLOSED:
		return not door_is_open(pos)
	return t == TileType.VOID or t == TileType.WALL or t == TileType.SERVER


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(from) or not is_in_bounds(to):
		return []
	if astar_enemy.is_point_solid(to):
		return []
	var out: Array[Vector2i] = []
	for p in astar_enemy.get_id_path(from, to):
		out.append(p)
	return out


# Ближайшая клетка, по которой может пройти охрана (для целей в шкафу/вентиляции).
func nearest_ai_cell(target: Vector2i, from: Vector2i) -> Vector2i:
	if is_walkable_for_ai(target):
		return target
	var best: Vector2i = from
	var best_len: int = 1 << 30
	for d in DIRS:
		var c: Vector2i = target + d
		if is_walkable_for_ai(c):
			var p: Array[Vector2i] = find_path(from, c)
			var l: int = p.size() if p.size() > 0 else (1 << 29)
			if from == c:
				l = 0
			if l < best_len:
				best_len = l
				best = c
	return best


func grid_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE + TILE_SIZE * 0.5, pos.y * TILE_SIZE + TILE_SIZE * 0.5)


func world_to_grid(w_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(w_pos.x / float(TILE_SIZE))), int(floor(w_pos.y / float(TILE_SIZE))))


static func rot_cw(d: Vector2i) -> Vector2i:
	# UP(0,-1)->RIGHT(1,0)->DOWN(0,1)->LEFT(-1,0)
	return Vector2i(-d.y, d.x)


static func rot_ccw(d: Vector2i) -> Vector2i:
	return Vector2i(d.y, -d.x)
