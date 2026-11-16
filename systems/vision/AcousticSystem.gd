# res://systems/vision/AcousticSystem.gd
# Распространение звука: заливка по клеткам (Manhattan), стены и закрытые двери глушат звук.
class_name AcousticSystem
extends RefCounted


static func flood(grid: GridManager, origin: Vector2i, radius: int) -> Dictionary:
	var dist: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = dist[cur]
		if d >= radius:
			continue
		for dir in GridManager.DIRS:
			var nxt: Vector2i = cur + dir
			if dist.has(nxt) or not grid.is_in_bounds(nxt):
				continue
			if grid.blocks_sound(nxt):
				continue
			dist[nxt] = d + 1
			queue.append(nxt)
	return dist


# Слышит ли охранник шум силы radius из клетки origin.
# Обычный охранник реагирует только на шум R>=2; элита слышит всё в окне 3x3 вокруг себя.
static func guard_hears(grid: GridManager, guard_pos: Vector2i, is_elite: bool,
		origin: Vector2i, radius: int, dist_map: Dictionary) -> bool:
	if radius < 1:
		return false
	var d: int = int(dist_map.get(guard_pos, 999))
	if is_elite:
		if d <= radius:
			return true
		var cheb: int = maxi(absi(guard_pos.x - origin.x), absi(guard_pos.y - origin.y))
		if cheb <= 1 and d <= 2:
			return true
		return false
	return radius >= 2 and d <= radius
