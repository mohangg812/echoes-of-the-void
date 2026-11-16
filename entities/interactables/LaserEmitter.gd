# res://entities/interactables/LaserEmitter.gd
# Лазерный излучатель в стене. Работает по строгому циклу ВКЛ/ВЫКЛ, луч идёт до стены или дыма.
class_name LaserEmitter
extends GridEntity

var on_turns: int = 1
var off_turns: int = 1
var phase: int = 0
var group_id: String = ""
var activate_on_loot: bool = false
var enabled: bool = true
var emp_turns: int = 0


func is_firing(sim: TurnManager, turn: int) -> bool:
	if not enabled or emp_turns > 0 or sim.is_group_off(group_id):
		return false
	var cycle: int = on_turns + off_turns
	if cycle <= 0:
		return true
	return ((turn + phase) % cycle) < on_turns


func beam_cells(grid: GridManager) -> Array[Vector2i]:
	return VisionCone2D.straight_ray(grid_pos, facing, 60, grid, true)


func get_state() -> Dictionary:
	return {"e": enabled, "m": emp_turns}


func set_state(d: Dictionary) -> void:
	enabled = d["e"]
	emp_turns = d["m"]
