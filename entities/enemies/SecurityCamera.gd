# res://entities/enemies/SecurityCamera.gd
# Камера на стене: поворачивается по заданной последовательности направлений каждые `period` ходов.
# Видит красную зону на range клеток под углом 60°, слуха нет. После кражи золота дальность +1.
class_name SecurityCamera
extends GridEntity

var facing_sequence: Array[Vector2i] = []
var period: int = 1
var group_id: String = ""
var base_range: int = 5
var half_angle: float = 30.0
var step_count: int = 0
var emp_turns: int = 0
var red_cells: Array[Vector2i] = []
var yellow_cells: Array[Vector2i] = []


func view_range(sim: TurnManager) -> int:
	return base_range + (1 if sim.loot_taken else 0)


func is_active(sim: TurnManager) -> bool:
	return emp_turns <= 0 and not sim.is_group_off(group_id)


func _apply_facing() -> void:
	if facing_sequence.is_empty():
		return
	var idx: int = (step_count / maxi(period, 1)) % facing_sequence.size()
	facing = facing_sequence[idx]


func step_turn(_sim: TurnManager) -> void:
	step_count += 1
	_apply_facing()


func recompute(sim: TurnManager, ignore_cell: Vector2i) -> void:
	if not is_active(sim):
		red_cells = []
		yellow_cells = []
		return
	var res: Dictionary = VisionCone2D.compute(grid_pos, facing, view_range(sim), half_angle, sim.grid, ignore_cell)
	red_cells = res["red"]
	yellow_cells = res["yellow"]


func get_state() -> Dictionary:
	return {"s": step_count, "f": facing, "m": emp_turns}


func set_state(d: Dictionary) -> void:
	step_count = d["s"]
	facing = d["f"]
	emp_turns = d["m"]
