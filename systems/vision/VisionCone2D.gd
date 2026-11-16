# res://systems/vision/VisionCone2D.gd
# Дискретный конус зрения: алгоритм Брезенхэма с защитой от «подглядывания» через сомкнутые углы стен.
# Результат — две зоны клеток: красная (прямое обнаружение) и жёлтая (подозрение).
# Рисуется отдельным слоем по тем же клеткам, поэтому конус не врёт про стены и дым.
class_name VisionCone2D
extends RefCounted

const NO_CELL: Vector2i = Vector2i(-9999, -9999)


static func compute(origin: Vector2i, facing: Vector2i, max_dist: int, half_angle_deg: float,
		grid: GridManager, ignore_cell: Vector2i = NO_CELL) -> Dictionary:
	var red: Array[Vector2i] = []
	var yellow: Array[Vector2i] = []
	var forward := Vector2(facing).normalized()
	var max_r: int = max_dist + 1
	for dy in range(-max_r, max_r + 1):
		for dx in range(-max_r, max_r + 1):
			if dx == 0 and dy == 0:
				continue
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if not grid.is_in_bounds(cell):
				continue
			var offset := Vector2(dx, dy)
			var dist: float = offset.length()
			if dist > float(max_dist) + 1.15:
				continue
			var angle_deg: float = rad_to_deg(acos(clampf(forward.dot(offset.normalized()), -1.0, 1.0)))
			if angle_deg > half_angle_deg + 18.0:
				continue
			if has_grid_line_of_sight(origin, cell, grid, ignore_cell):
				if dist <= float(max_dist) + 0.001 and angle_deg <= half_angle_deg + 0.01:
					red.append(cell)
				else:
					yellow.append(cell)
	return {"red": red, "yellow": yellow}


static func has_grid_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, grid: GridManager,
		ignore_cell: Vector2i = NO_CELL) -> bool:
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		var cur := Vector2i(x0, y0)
		if cur != from_cell and cur != ignore_cell:
			if grid.blocks_vision(cur):
				return false
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		# Защита от диагонального прострела сквозь сомкнутые углы стен.
		if e2 >= dy and e2 <= dx:
			if grid.blocks_vision(Vector2i(x0 + sx, y0)) and grid.blocks_vision(Vector2i(x0, y0 + sy)):
				return false
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true


# Луч турели/лазера по прямой: клетки до первого препятствия.
static func straight_ray(origin: Vector2i, dir: Vector2i, max_len: int, grid: GridManager,
		beam: bool = false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cell: Vector2i = origin + dir
	var n: int = 0
	while n < max_len and grid.is_in_bounds(cell):
		var blocked: bool = grid.blocks_beam(cell) if beam else grid.blocks_vision(cell)
		if blocked:
			break
		out.append(cell)
		cell += dir
		n += 1
	return out
