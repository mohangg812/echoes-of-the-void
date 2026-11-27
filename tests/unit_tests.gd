# tests/unit_tests.gd
# Headless unit + integration tests for the deterministic simulation core.
#
# Run:
#   godot --headless --path . --script res://tests/unit_tests.gd
#
# Exit code 0 — all checks passed, 1 — at least one failure.
# No external test framework/plugin is required.
extends SceneTree

var checks: int = 0
var failures: int = 0
var current_test: String = ""


func _init() -> void:
	var tests: Array[String] = [
		"test_grid_layout_and_bounds",
		"test_grid_walkability",
		"test_grid_blockers",
		"test_grid_coordinates_and_rotation",
		"test_grid_pathfinding",
		"test_vision_cone",
		"test_vision_blockers",
		"test_vision_corner_and_ignore",
		"test_straight_ray",
		"test_acoustic_flood",
		"test_acoustic_hearing",
		"test_alarm_manager",
		"test_tactical_history",
		"test_invalid_action_keeps_turn",
		"test_move_and_wait",
		"test_dash_rules",
		"test_vent_two_step",
		"test_closet_exposure",
		"test_takedown_rules",
		"test_interact_switch",
		"test_doors",
		"test_smoke_gadget",
		"test_decoy_gadget",
		"test_emp_gadget",
		"test_cloak_gadget",
		"test_pickups",
		"test_pickpocket",
		"test_guard_detection",
		"test_guard_suspicion",
		"test_alarm_cooldown",
		"test_camera_detection_and_rotation",
		"test_turret",
		"test_laser",
		"test_victory_and_loss",
		"test_snapshot_undo_and_preview",
		"test_style_and_rating",
		"test_campaign_levels_load",
		"test_campaign_solutions_replay",
		"test_level_loader_validation",
	]

	for name in tests:
		current_test = name
		var before := failures
		call(name)
		var mark := "OK  " if failures == before else "FAIL"
		print("%s  %s" % [mark, name])
		if failures > 0:
			print("      failures so far: %d" % failures)
	print("")
	print("checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)


# ───────────────────────────── helpers ─────────────────────────────

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("  [%s] %s" % [current_test, message])


func eq(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		printerr("  [%s] %s: expected <%s>, got <%s>" % [current_test, message, str(expected), str(actual)])


func v2(actual: Vector2i, expected: Vector2i, message: String) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		printerr("  [%s] %s: expected %s, got %s" % [current_test, message, expected, actual])


func arr_has(value: Variant, item: Variant, message: String) -> void:
	checks += 1
	if not (value as Array).has(item):
		failures += 1
		printerr("  [%s] %s: missing <%s>" % [current_test, message, str(item)])


func arr_not_has(value: Variant, item: Variant, message: String) -> void:
	checks += 1
	if (value as Array).has(item):
		failures += 1
		printerr("  [%s] %s: unexpected <%s>" % [current_test, message, str(item)])


func has_event(events: Array, type: String) -> bool:
	for e in events:
		if String((e as Dictionary).get("t", "")) == type:
			return true
	return false


func make_sim(layout: Array, extra: Dictionary = {}) -> TurnManager:
	var data: Dictionary = {
		"level_id": 0,
		"title": "unit-test",
		"par_turns": 40,
		"starting_gadgets": {"smoke": 1, "decoy": 1, "emp": 1, "cloak": 1, "shock": 1},
		"layout": layout,
	}
	data.merge(extra, true)
	return LevelLoader.build(data)


func room_layout(w: int, h: int, start: Vector2i = Vector2i(1, 1), gold: Vector2i = Vector2i(-1, -1)) -> Array:
	var rows: Array = []
	for y in range(h):
		var row: String = ""
		for x in range(w):
			var p := Vector2i(x, y)
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				row += "#"
			elif p == start:
				row += "E"
			elif p == gold:
				row += "G"
			else:
				row += "."
		rows.append(row)
	return rows


func wait(sim: TurnManager) -> Dictionary:
	return sim.execute_player_turn({"type": "wait"})


# ───────────────────────────── grid ─────────────────────────────

func test_grid_layout_and_bounds() -> void:
	var g := GridManager.new()
	g.load_layout(["###", "#E#", "#.#", "###"])
	eq(g.width, 3, "width from layout")
	eq(g.height, 4, "height from layout")
	eq(g.get_tile(Vector2i(0, 0)), GridManager.TileType.WALL, "wall tile")
	v2(Vector2i(1, 1), Vector2i(1, 1), "coordinates are (x, y)")
	eq(g.get_tile(Vector2i(1, 1)), GridManager.TileType.EXTRACTION, "extraction tile")
	eq(g.get_tile(Vector2i(1, 2)), GridManager.TileType.FLOOR, "floor tile")
	eq(g.get_tile(Vector2i(-1, 0)), GridManager.TileType.WALL, "negative x is solid wall")
	eq(g.get_tile(Vector2i(3, 0)), GridManager.TileType.WALL, "out of bounds is wall")
	eq(int(GridManager.CHAR_TO_TILE["V"]), GridManager.TileType.VENT, "V maps to vent")
	eq(int(GridManager.CHAR_TO_TILE["H"]), GridManager.TileType.HAZARD, "H maps to hazard")
	var unknown := GridManager.new()
	unknown.load_layout(["?"])
	eq(unknown.get_tile(Vector2i(0, 0)), GridManager.TileType.FLOOR, "unknown chars fall back to floor")


func test_grid_walkability() -> void:
	var g := GridManager.new()
	g.load_layout([
		"#########",
		"#.=VSCHG#",
		"#...#...#",
		"#########",
	])
	check(g.is_walkable_for_player(Vector2i(1, 1), []), "floor is walkable for player")
	check(not g.is_walkable_for_player(Vector2i(2, 1), []), "glass wall is not walkable")
	check(g.is_walkable_for_player(Vector2i(3, 1), []), "vent is walkable for player")
	check(not g.is_walkable_for_player(Vector2i(4, 1), []), "server is not walkable")
	check(g.is_walkable_for_player(Vector2i(5, 1), []), "closet is walkable")
	check(g.is_walkable_for_player(Vector2i(6, 1), []), "hazard is walkable")
	check(g.is_walkable_for_player(Vector2i(7, 1), []), "vault floor is walkable")
	check(not g.is_walkable_for_player(Vector2i(0, 1), []), "wall is not walkable")
	check(not g.is_walkable_for_player(Vector2i(-1, 1), []), "out of bounds is not walkable")

	check(not g.is_walkable_for_ai(Vector2i(2, 1)), "AI cannot walk through glass")
	check(g.is_walkable_for_ai(Vector2i(6, 1)), "AI can walk on hazard")
	check(not g.is_walkable_for_ai(Vector2i(5, 1)), "AI cannot walk into closet")

	var door_pos := Vector2i(2, 2)
	var door := ElectronicDoor.new()
	door.grid_pos = door_pos
	door.required_keycard = "RED"
	g.set_tile(door_pos, GridManager.TileType.DOOR_CLOSED)
	g.doors[door_pos] = door
	check(not g.is_walkable_for_player(door_pos, []), "locked door blocks player without keycard")
	check(g.is_walkable_for_player(door_pos, ["RED"]), "locked door opens with matching keycard")
	door.key_open = true
	check(g.is_walkable_for_player(door_pos, []), "open door is walkable")
	check(g.is_walkable_for_ai(door_pos), "AI treats closed doors as walkable")

	var floor_pos := Vector2i(1, 2)
	g.solid_entities[floor_pos] = true
	check(not g.is_walkable_for_player(floor_pos, []), "solid entity blocks player")
	check(not g.is_walkable_for_ai(floor_pos), "solid entity blocks AI")


func test_grid_blockers() -> void:
	var g := GridManager.new()
	g.load_layout([
		"#######",
		"#.=VSC#",
		"#.....#",
		"#######",
	])
	check(g.blocks_vision(Vector2i(0, 1)), "wall blocks vision")
	check(g.blocks_beam(Vector2i(0, 1)), "wall blocks beam")
	check(g.blocks_sound(Vector2i(0, 1)), "wall blocks sound")

	check(not g.blocks_vision(Vector2i(2, 1)), "glass does not block vision")
	check(not g.blocks_beam(Vector2i(2, 1)), "glass does not block beam")
	check(not g.blocks_sound(Vector2i(2, 1)), "glass does not block sound")

	check(g.blocks_vision(Vector2i(3, 1)), "vent blocks vision")
	check(g.blocks_beam(Vector2i(3, 1)), "vent blocks beam")
	check(not g.blocks_sound(Vector2i(3, 1)), "vent does not block sound")

	check(g.blocks_vision(Vector2i(4, 1)), "server blocks vision")
	check(g.blocks_beam(Vector2i(4, 1)), "server blocks beam")
	check(g.blocks_sound(Vector2i(4, 1)), "server blocks sound")

	check(g.blocks_vision(Vector2i(5, 1)), "closet blocks vision")
	check(g.blocks_beam(Vector2i(5, 1)), "closet blocks beam")
	check(not g.blocks_sound(Vector2i(5, 1)), "closet does not block sound")

	var door_pos := Vector2i(3, 2)
	var door := ElectronicDoor.new()
	door.grid_pos = door_pos
	g.set_tile(door_pos, GridManager.TileType.DOOR_CLOSED)
	g.doors[door_pos] = door
	check(g.blocks_vision(door_pos), "closed door blocks vision")
	check(g.blocks_beam(door_pos), "closed door blocks beam")
	check(g.blocks_sound(door_pos), "closed door blocks sound")
	door.key_open = true
	check(not g.blocks_vision(door_pos), "open door does not block vision")
	check(not g.blocks_beam(door_pos), "open door does not block beam")
	check(not g.blocks_sound(door_pos), "open door does not block sound")

	var smoke_pos := Vector2i(4, 2)
	g.smoke_cells[smoke_pos] = 3
	check(g.blocks_vision(smoke_pos), "smoke blocks vision")
	check(g.blocks_beam(smoke_pos), "smoke blocks beam")

	var void_grid := GridManager.new()
	void_grid.init_grid(3, 3)
	check(void_grid.blocks_vision(Vector2i(1, 1)), "void blocks vision")
	check(void_grid.blocks_beam(Vector2i(1, 1)), "void blocks beam")
	check(void_grid.blocks_sound(Vector2i(1, 1)), "void blocks sound")


func test_grid_coordinates_and_rotation() -> void:
	var g := GridManager.new()
	g.load_layout(["###", "#.#", "###"])
	eq(GridManager.TILE_SIZE, 48, "tile size is 48")
	eq(g.grid_to_world(Vector2i(0, 0)), Vector2(24, 24), "cell center")
	eq(g.grid_to_world(Vector2i(3, 4)), Vector2(168, 216), "cell center with offset")
	v2(g.world_to_grid(Vector2(0, 0)), Vector2i(0, 0), "world origin")
	v2(g.world_to_grid(Vector2(47.9, 47.9)), Vector2i(0, 0), "floor inside tile")
	v2(g.world_to_grid(Vector2(48, 48)), Vector2i(1, 1), "next tile boundary")
	v2(g.world_to_grid(g.grid_to_world(Vector2i(5, 7))), Vector2i(5, 7), "roundtrip")

	var up := Vector2i(0, -1)
	var right := Vector2i(1, 0)
	var down := Vector2i(0, 1)
	var left := Vector2i(-1, 0)
	v2(GridManager.rot_cw(up), right, "rotate up -> right")
	v2(GridManager.rot_cw(right), down, "rotate right -> down")
	v2(GridManager.rot_cw(down), left, "rotate down -> left")
	v2(GridManager.rot_cw(left), up, "rotate left -> up")
	v2(GridManager.rot_ccw(right), up, "rotate ccw right -> up")
	v2(GridManager.rot_ccw(GridManager.rot_cw(up)), up, "rotations are inverse")

	var e := GridEntity.new()
	e.grid_pos = Vector2i(2, 2)
	e.face_towards(Vector2i(5, 3))
	v2(e.facing, right, "face towards dominant x axis")
	e.face_towards(Vector2i(3, 6))
	v2(e.facing, down, "face towards dominant y axis")
	e.face_towards(Vector2i(2, 2))
	v2(e.facing, down, "face towards same cell keeps facing")


func test_grid_pathfinding() -> void:
	var g := GridManager.new()
	g.load_layout([
		"#######",
		"#..#..#",
		"#..#..#",
		"#.....#",
		"#######",
	])
	var path: Array[Vector2i] = g.find_path(Vector2i(1, 1), Vector2i(4, 1))
	check(path.size() > 4, "path detours around walls")
	if path.size() > 0:
		v2(path[0], Vector2i(1, 1), "path starts at source")
		v2(path[path.size() - 1], Vector2i(4, 1), "path ends at target")
	var connected := true
	for i in range(1, path.size()):
		connected = connected and absi(path[i].x - path[i - 1].x) + absi(path[i].y - path[i - 1].y) == 1
	check(connected, "path consists of orthogonal steps")
	check(g.find_path(Vector2i(1, 1), Vector2i(3, 1)).is_empty(), "path to wall is empty")
	check(g.find_path(Vector2i(-1, 1), Vector2i(1, 1)).is_empty(), "path from out of bounds is empty")

	var g2 := GridManager.new()
	g2.load_layout([
		"#######",
		"#..C..#",
		"#.....#",
		"#######",
	])
	var near := g2.nearest_ai_cell(Vector2i(3, 1), Vector2i(1, 1))
	check(g2.is_walkable_for_ai(near), "nearest AI cell is walkable")
	check(absi(near.x - 3) + absi(near.y - 1) == 1, "nearest AI cell is adjacent to closet")


# ───────────────────────────── vision & sound ─────────────────────────────

func test_vision_cone() -> void:
	var sim := make_sim(room_layout(9, 7, Vector2i(1, 1)))
	var res := VisionCone2D.compute(Vector2i(2, 4), Vector2i(1, 0), 3, 45.0, sim.grid)
	var red: Array = res["red"]
	var yellow: Array = res["yellow"]
	arr_has(red, Vector2i(3, 4), "cell directly ahead is red")
	arr_has(red, Vector2i(5, 4), "cell at max range is red")
	arr_not_has(red, Vector2i(6, 4), "cell beyond range is not red")
	arr_not_has(red, Vector2i(1, 4), "cell behind the guard is not red")
	arr_not_has(red, Vector2i(2, 2), "cell at 90 degrees is outside the cone")
	arr_has(yellow, Vector2i(4, 1), "cell just outside half-angle is yellow")
	arr_not_has(red, Vector2i(4, 1), "yellow cell is not red")
	for c in red:
		check(sim.grid.is_in_bounds(c), "red cell is in bounds")

	var res_left := VisionCone2D.compute(Vector2i(2, 4), Vector2i(-1, 0), 3, 45.0, sim.grid)
	arr_has(res_left["red"], Vector2i(1, 4), "facing left sees left")
	arr_not_has(res_left["red"], Vector2i(3, 4), "facing left does not see right")


func test_vision_blockers() -> void:
	var g := GridManager.new()
	g.load_layout([
		"#########",
		"#.......#",
		"#.......#",
		"#.......#",
		"#.......#",
		"#########",
	])
	var origin := Vector2i(2, 2)
	var res := VisionCone2D.compute(origin, Vector2i(1, 0), 4, 45.0, g)
	arr_has(res["red"], Vector2i(3, 2), "clear cell is visible")

	g.set_tile(Vector2i(4, 2), GridManager.TileType.WALL)
	res = VisionCone2D.compute(origin, Vector2i(1, 0), 4, 45.0, g)
	arr_not_has(res["red"], Vector2i(4, 2), "wall cell itself is not visible")
	arr_not_has(res["red"], Vector2i(5, 2), "wall blocks vision behind it")

	g.set_tile(Vector2i(4, 2), GridManager.TileType.GLASS_WALL)
	res = VisionCone2D.compute(origin, Vector2i(1, 0), 4, 45.0, g)
	arr_has(res["red"], Vector2i(5, 2), "glass is transparent for vision")

	g.set_tile(Vector2i(4, 2), GridManager.TileType.FLOOR)
	g.smoke_cells[Vector2i(4, 2)] = 3
	res = VisionCone2D.compute(origin, Vector2i(1, 0), 4, 45.0, g)
	arr_not_has(res["red"], Vector2i(4, 2), "smoke cell is not visible")
	arr_not_has(res["red"], Vector2i(5, 2), "smoke blocks vision behind it")
	g.smoke_cells.erase(Vector2i(4, 2))

	var door := ElectronicDoor.new()
	door.grid_pos = Vector2i(4, 2)
	g.set_tile(door.grid_pos, GridManager.TileType.DOOR_CLOSED)
	g.doors[door.grid_pos] = door
	res = VisionCone2D.compute(origin, Vector2i(1, 0), 4, 45.0, g)
	arr_not_has(res["red"], Vector2i(5, 2), "closed door blocks vision")
	door.key_open = true
	res = VisionCone2D.compute(origin, Vector2i(1, 0), 4, 45.0, g)
	arr_has(res["red"], Vector2i(5, 2), "open door lets vision through")


func test_vision_corner_and_ignore() -> void:
	var g := GridManager.new()
	g.load_layout([
		"#####",
		"#...#",
		"#...#",
		"#...#",
		"#####",
	])
	check(VisionCone2D.has_grid_line_of_sight(Vector2i(1, 1), Vector2i(2, 2), g), "open diagonal LOS")
	g.set_tile(Vector2i(2, 1), GridManager.TileType.WALL)
	g.set_tile(Vector2i(1, 2), GridManager.TileType.WALL)
	check(not VisionCone2D.has_grid_line_of_sight(Vector2i(1, 1), Vector2i(2, 2), g), "no peek through a closed corner")

	var g2 := GridManager.new()
	g2.load_layout([
		"#####",
		"#...#",
		"#...#",
		"#...#",
		"#####",
	])
	g2.smoke_cells[Vector2i(2, 2)] = 3
	check(not VisionCone2D.has_grid_line_of_sight(Vector2i(1, 2), Vector2i(3, 2), g2), "smoke blocks LOS")
	check(VisionCone2D.has_grid_line_of_sight(Vector2i(1, 2), Vector2i(3, 2), g2, Vector2i(2, 2)),
		"ignore cell bypasses the player's own cell")
	check(VisionCone2D.has_grid_line_of_sight(Vector2i(1, 2), Vector2i(2, 2), g2, Vector2i(2, 2)),
		"target cell can be ignored")


func test_straight_ray() -> void:
	var g := GridManager.new()
	g.load_layout([
		"#######",
		"#.....#",
		"#.....#",
		"#######",
	])
	var ray := VisionCone2D.straight_ray(Vector2i(1, 2), Vector2i(1, 0), 4, g, false)
	eq(ray.size(), 4, "ray length is capped by max_len")
	v2(ray[0], Vector2i(2, 2), "ray starts in front of origin")
	v2(ray[3], Vector2i(5, 2), "ray ends at max range")

	g.set_tile(Vector2i(3, 2), GridManager.TileType.WALL)
	ray = VisionCone2D.straight_ray(Vector2i(1, 2), Vector2i(1, 0), 4, g, false)
	eq(ray.size(), 1, "vision ray stops before wall")

	g.set_tile(Vector2i(3, 2), GridManager.TileType.GLASS_WALL)
	ray = VisionCone2D.straight_ray(Vector2i(1, 2), Vector2i(1, 0), 4, g, true)
	eq(ray.size(), 4, "beam passes through glass")

	g.set_tile(Vector2i(3, 2), GridManager.TileType.VENT)
	ray = VisionCone2D.straight_ray(Vector2i(1, 2), Vector2i(1, 0), 4, g, true)
	eq(ray.size(), 1, "beam stops at vent")
	ray = VisionCone2D.straight_ray(Vector2i(1, 2), Vector2i(1, 0), 4, g, false)
	eq(ray.size(), 1, "vision stops at vent")

	g.set_tile(Vector2i(3, 2), GridManager.TileType.FLOOR)
	g.smoke_cells[Vector2i(3, 2)] = 1
	ray = VisionCone2D.straight_ray(Vector2i(1, 2), Vector2i(1, 0), 4, g, true)
	eq(ray.size(), 1, "beam stops at smoke")


func test_acoustic_flood() -> void:
	var sim := make_sim(room_layout(9, 7, Vector2i(1, 1)))
	var origin := Vector2i(3, 3)
	var dist := AcousticSystem.flood(sim.grid, origin, 2)
	eq(dist.size(), 13, "radius-2 diamond has 13 cells")
	eq(int(dist.get(origin, -1)), 0, "origin distance is zero")
	eq(int(dist.get(Vector2i(3, 5), -1)), 2, "distance two cells below origin")
	check(not dist.has(Vector2i(3, 6)), "outside radius is not flooded")

	var g := GridManager.new()
	g.load_layout([
		"#######",
		"#..#..#",
		"#..#..#",
		"#..#..#",
		"#######",
	])
	var blocked := AcousticSystem.flood(g, Vector2i(2, 2), 4)
	check(blocked.has(Vector2i(2, 1)), "sound travels around on its side")
	check(not blocked.has(Vector2i(4, 2)), "wall divider blocks sound")
	check(not blocked.has(Vector2i(5, 2)), "wall divider blocks cells behind it")

	var g2 := GridManager.new()
	g2.load_layout([
		"#######",
		"#..#..#",
		"#..#..#",
		"#######",
	])
	var door := ElectronicDoor.new()
	door.grid_pos = Vector2i(3, 2)
	g2.set_tile(door.grid_pos, GridManager.TileType.DOOR_CLOSED)
	g2.doors[door.grid_pos] = door
	var through_closed := AcousticSystem.flood(g2, Vector2i(2, 2), 4)
	check(not through_closed.has(Vector2i(4, 2)), "closed door blocks sound")
	door.key_open = true
	var through_open := AcousticSystem.flood(g2, Vector2i(2, 2), 4)
	check(through_open.has(Vector2i(4, 2)), "open door passes sound")


func test_acoustic_hearing() -> void:
	var sim := make_sim(room_layout(9, 7, Vector2i(1, 1)))
	var origin := Vector2i(2, 2)
	var dist := AcousticSystem.flood(sim.grid, origin, 5)
	check(not AcousticSystem.guard_hears(sim.grid, Vector2i(2, 3), false, origin, 1, dist),
		"normal guard ignores quiet noise")
	check(AcousticSystem.guard_hears(sim.grid, Vector2i(2, 3), false, origin, 2, dist),
		"normal guard hears radius-2 noise at distance 1")
	check(not AcousticSystem.guard_hears(sim.grid, Vector2i(5, 2), false, origin, 2, dist),
		"normal guard does not hear beyond radius")
	check(AcousticSystem.guard_hears(sim.grid, Vector2i(3, 2), true, origin, 1, dist),
		"elite hears adjacent quiet noise")
	check(AcousticSystem.guard_hears(sim.grid, Vector2i(3, 3), true, origin, 1, dist),
		"elite special 3x3 hearing")
	check(not AcousticSystem.guard_hears(sim.grid, Vector2i(6, 2), true, origin, 1, dist),
		"elite does not hear across the room")

	var g := GridManager.new()
	g.load_layout([
		"#######",
		"#..#..#",
		"#..#..#",
		"#######",
	])
	var blocked := AcousticSystem.flood(g, Vector2i(2, 2), 5)
	check(not AcousticSystem.guard_hears(g, Vector2i(5, 2), false, Vector2i(2, 2), 5, blocked),
		"guard behind a wall does not hear")


# ───────────────────────────── managers ─────────────────────────────

func test_alarm_manager() -> void:
	var a := AlarmManager.new()
	eq(a.state, AlarmManager.State.STEALTH, "alarm starts in stealth")
	check(not a.is_alarm(), "stealth is not alarm")
	var pos := Vector2i(3, 4)
	check(a.trigger(pos), "first trigger starts alarm")
	check(a.is_alarm(), "alarm is active")
	eq(a.times_triggered, 1, "first trigger counted")
	eq(a.cooldown, AlarmManager.COOLDOWN_TURNS, "trigger sets cooldown")
	v2(a.last_known_player_pos, pos, "last known position stored")
	check(not a.trigger(Vector2i(4, 4)), "second trigger while active is not fresh")
	eq(a.times_triggered, 1, "repeated trigger does not increment counter")
	v2(a.last_known_player_pos, Vector2i(4, 4), "repeated trigger updates position")
	check(not a.step_turn_cooldown(false, pos), "cooldown tick does not end alarm early")
	eq(a.cooldown, AlarmManager.COOLDOWN_TURNS - 1, "cooldown decrements")
	check(not a.step_turn_cooldown(true, pos), "being seen refreshes cooldown")
	eq(a.cooldown, AlarmManager.COOLDOWN_TURNS, "seen player resets cooldown")
	for _i in range(6):
		a.step_turn_cooldown(false, pos)
	eq(a.state, AlarmManager.State.STEALTH, "alarm resets after 6 unseen turns")
	check(not a.is_alarm(), "reset alarm is not active")

	a.trigger(pos)
	var state := a.get_state()
	var b := AlarmManager.new()
	b.set_state(state)
	eq(b.state, a.state, "snapshot restores state")
	eq(b.cooldown, a.cooldown, "snapshot restores cooldown")
	v2(b.last_known_player_pos, a.last_known_player_pos, "snapshot restores position")
	eq(b.times_triggered, a.times_triggered, "snapshot restores counter")


func test_tactical_history() -> void:
	var h := TacticalHistory.new()
	eq(h.size(), 0, "history is empty")
	eq(h.pop(), {}, "pop on empty returns empty dict")
	h.push({"i": 1})
	h.push({"i": 2})
	eq(h.size(), 2, "history size")
	eq(int(h.pop().get("i", -1)), 2, "pop is LIFO")
	eq(int(h.pop().get("i", -1)), 1, "pop is LIFO after second pop")
	eq(h.size(), 0, "history is empty after pops")
	h.clear()
	eq(h.size(), 0, "clear empties history")

	for i in range(TacticalHistory.MAX_DEPTH + 5):
		h.push({"i": i})
	eq(h.size(), TacticalHistory.MAX_DEPTH, "history is capped")
	eq(int(h.stack[0].get("i", -1)), 5, "oldest entries are dropped")
	eq(int(h.pop().get("i", -1)), TacticalHistory.MAX_DEPTH + 4, "newest entry remains")
	h.clear()


# ───────────────────────────── player actions ─────────────────────────────

func test_invalid_action_keeps_turn() -> void:
	var sim := make_sim(room_layout(7, 5))
	var r := sim.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	check(not r["ok"], "moving into wall fails")
	eq(sim.turn_number, 0, "invalid move does not consume a turn")
	v2(sim.player.grid_pos, Vector2i(1, 1), "invalid move does not move player")
	eq(sim.history.size(), 0, "invalid move does not push history")
	check((r["events"] as Array).is_empty(), "invalid move produces no events")

	r = sim.execute_player_turn({"type": "dance"})
	check(not r["ok"], "unknown action fails")
	eq(sim.turn_number, 0, "unknown action does not consume a turn")

	r = sim.execute_player_turn({"type": "dash", "dir": Vector2i(-1, 0)})
	check(not r["ok"], "dash into wall fails")
	eq(sim.turn_number, 0, "invalid dash does not consume a turn")


func test_move_and_wait() -> void:
	var sim := make_sim(room_layout(7, 5))
	var r := wait(sim)
	check(r["ok"], "wait succeeds")
	eq(sim.turn_number, 1, "wait consumes a turn")
	eq(sim.current_phase, TurnManager.TurnPhase.AWAITING_INPUT, "phase returns to awaiting input")

	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "move right succeeds")
	v2(sim.player.grid_pos, Vector2i(2, 1), "player moved right")
	v2(sim.player.facing, Vector2i(1, 0), "facing updated")
	eq(sim.turn_number, 2, "move consumes a turn")
	check(has_event(r["events"], "step"), "move emits step event")

	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(0, 1)})
	check(r["ok"], "move down succeeds")
	v2(sim.player.grid_pos, Vector2i(2, 2), "player moved down")
	v2(sim.player.facing, Vector2i(0, 1), "facing updated down")


func test_dash_rules() -> void:
	var sim := make_sim(room_layout(9, 7))
	var r := sim.execute_player_turn({"type": "dash", "dir": Vector2i(1, 0)})
	check(r["ok"], "dash over two free cells succeeds")
	v2(sim.player.grid_pos, Vector2i(3, 1), "dash moves two cells")
	eq(sim.player.dash_cd, PlayerController.DASH_COOLDOWN - 1, "dash cooldown ticks on the dash turn")
	eq(int(sim.stats["dash"]), 1, "dash counter")
	check(has_event(r["events"], "dash"), "dash event")
	eq(sim.turn_number, 1, "dash consumes one turn")

	r = sim.execute_player_turn({"type": "dash", "dir": Vector2i(1, 0)})
	check(not r["ok"], "dash during cooldown fails")
	eq(sim.turn_number, 1, "failed dash does not consume a turn")
	v2(sim.player.grid_pos, Vector2i(3, 1), "failed dash does not move")

	for _i in range(PlayerController.DASH_COOLDOWN - 1):
		wait(sim)
	eq(sim.player.dash_cd, 0, "cooldown expires after waiting")
	r = sim.execute_player_turn({"type": "dash", "dir": Vector2i(1, 0)})
	check(r["ok"], "dash works after cooldown")
	v2(sim.player.grid_pos, Vector2i(5, 1), "second dash moves two cells")

	var blocked := make_sim(room_layout(9, 7))
	blocked.grid.solid_entities[Vector2i(2, 1)] = true
	r = blocked.execute_player_turn({"type": "dash", "dir": Vector2i(1, 0)})
	check(not r["ok"], "dash is blocked by solid entity")
	eq(blocked.turn_number, 0, "blocked dash does not consume a turn")


func test_vent_two_step() -> void:
	var sim := make_sim([
		"#######",
		"#EV...#",
		"#.....#",
		"#######",
	])
	var r := sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "first vent move is accepted as preparation")
	v2(sim.player.grid_pos, Vector2i(1, 1), "player does not enter vent immediately")
	check(has_event(r["events"], "vent_prep"), "vent preparation event")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "second vent move enters the vent")
	v2(sim.player.grid_pos, Vector2i(2, 1), "player is inside vent")
	check(sim.player.is_in_vent(sim), "player is in vent")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "leaving vent is a normal move")
	v2(sim.player.grid_pos, Vector2i(3, 1), "player left vent")
	check(not sim.player.is_in_vent(sim), "player is no longer in vent")


func test_closet_exposure() -> void:
	var seen_sim := make_sim([
		"########",
		"#.EC...#",
		"#......#",
		"########",
	], {
		"guards": [{"type": "standard", "start": [1, 1], "facing": [1, 0], "waypoints": [[1, 1]]}],
	})
	var r := seen_sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "move into closet succeeds")
	v2(seen_sim.player.grid_pos, Vector2i(3, 1), "player is in closet")
	check(seen_sim.player.closet_exposed, "closet entered while seen is exposed")
	check(has_event(r["events"], "closet_exposed"), "closet exposure event")

	var hidden_sim := make_sim([
		"########",
		"#.EC...#",
		"#......#",
		"########",
	])
	hidden_sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(not hidden_sim.player.closet_exposed, "closet entered unseen is hidden")
	hidden_sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	v2(hidden_sim.player.grid_pos, Vector2i(4, 1), "player leaves closet")
	check(not hidden_sim.player.closet_exposed, "exposure resets after leaving closet")


func test_takedown_rules() -> void:
	var sim := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [3, 2], "facing": [1, 0], "waypoints": [[3, 2]]}],
	})
	var r := sim.execute_player_turn({"type": "takedown"})
	check(r["ok"], "takedown from behind succeeds")
	eq(sim.guards[0].state, BaseEnemy.AIState.STUNNED, "guard is stunned")
	eq(sim.guards[0].stun_turns, 5, "stun counter ticked once")
	eq(int(sim.player.gadgets["shock"]), 0, "shock charge consumed")
	eq(int(sim.stats["takedowns"]), 1, "takedown counter")
	eq(int(sim.stats["maxmult"]), 1, "style multiplier started")
	check(has_event(r["events"], "stun"), "stun event")
	r = sim.execute_player_turn({"type": "takedown"})
	check(not r["ok"], "cannot shock an already stunned guard")
	eq(sim.turn_number, 1, "failed takedown does not consume a turn")

	var front := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [3, 2], "facing": [-1, 0], "waypoints": [[3, 2]]}],
	})
	r = front.execute_player_turn({"type": "takedown"})
	check(not r["ok"], "takedown from the front fails")
	eq(front.turn_number, 0, "failed frontal takedown does not consume a turn")

	var elite := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "elite", "start": [3, 2], "facing": [1, 0], "waypoints": [[3, 2]]}],
	})
	r = elite.execute_player_turn({"type": "takedown"})
	check(not r["ok"], "elite guard is immune to shocker")

	var empty := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [3, 2], "facing": [1, 0], "waypoints": [[3, 2]]}],
	})
	empty.player.gadgets["shock"] = 0
	r = empty.execute_player_turn({"type": "takedown"})
	check(not r["ok"], "takedown needs a shock charge")
	eq(empty.turn_number, 0, "empty shocker does not consume a turn")


func test_interact_switch() -> void:
	var sim := make_sim([
		"#####",
		"#SE.#",
		"#...#",
		"#####",
	], {
		"switches": [{"pos": [1, 1], "target_group_id": "PWR", "description": "Power"}],
	})
	var r := sim.execute_player_turn({"type": "interact"})
	check(r["ok"], "interact with adjacent switch succeeds")
	check(sim.switches[0].on, "switch turns on")
	check(has_event(r["events"], "switch"), "switch event")
	eq(sim.turn_number, 1, "interact consumes a turn")
	r = sim.execute_player_turn({"type": "interact"})
	check(r["ok"], "interact toggles switch again")
	check(not sim.switches[0].on, "switch turns off")

	sim.execute_player_turn({"type": "move", "dir": Vector2i(0, 1)})
	r = sim.execute_player_turn({"type": "interact"})
	check(not r["ok"], "interact fails when nothing is nearby")
	eq(sim.turn_number, 3, "failed interact does not consume a turn")


func test_doors() -> void:
	var sim := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"doors": [{"pos": [3, 2], "required_keycard": "RED"}],
	})
	var r := sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(not r["ok"], "locked door blocks movement without keycard")
	eq(sim.turn_number, 0, "blocked door does not consume a turn")
	sim.player.keycards.append("RED")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "door opens with matching keycard")
	check(sim.doors[0].key_open, "door key_open flag")
	check(has_event(r["events"], "door_open"), "door_open event")
	v2(sim.player.grid_pos, Vector2i(3, 2), "player moved through door")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "player can leave the door cell")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	check(r["ok"], "open door can be re-entered")

	var power := make_sim([
		"#####",
		"#S..#",
		"#E..#",
		"#####",
	], {
		"switches": [{"pos": [1, 1], "target_group_id": "PWR"}],
		"doors": [{"pos": [2, 2], "group_id": "PWR"}],
	})
	r = power.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(not r["ok"], "powered door stays locked without power")
	check(not power.doors[0].group_open, "door group is closed")
	power.execute_player_turn({"type": "interact"})
	check(power.switches[0].on, "power switch is on")
	check(power.doors[0].group_open, "power switch opens door group")
	r = power.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "player passes through powered door")
	power.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	power.execute_player_turn({"type": "interact"})
	check(not power.doors[0].group_open, "turning power off closes the door group")
	r = power.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(not r["ok"], "door blocks again after power off")


func test_smoke_gadget() -> void:
	var sim := make_sim(room_layout(9, 7))
	var target := Vector2i(3, 1)
	var r := sim.execute_player_turn({"type": "gadget", "slot": 1, "target": target})
	check(r["ok"], "smoke grenade is thrown")
	eq(int(sim.player.gadgets["smoke"]), 0, "smoke charge consumed")
	eq(int(sim.stats["gadgets"]), 1, "gadget counter")
	check(has_event(r["events"], "smoke"), "smoke event")
	check(sim.grid.smoke_cells.has(target), "smoke covers target")
	eq(int(sim.grid.smoke_cells[target]), TurnManager.SMOKE_TURNS - 1, "smoke timer ticks after deploy")
	check(not VisionCone2D.has_grid_line_of_sight(Vector2i(1, 1), target, sim.grid),
		"smoke blocks line of sight")
	wait(sim)
	wait(sim)
	check(sim.grid.smoke_cells.is_empty(), "smoke expires after three turns")

	var far := make_sim(room_layout(9, 7))
	r = far.execute_player_turn({"type": "gadget", "slot": 1, "target": Vector2i(5, 1)})
	check(not r["ok"], "smoke beyond three cells fails")
	eq(far.turn_number, 0, "failed smoke does not consume a turn")
	eq(int(far.player.gadgets["smoke"]), 1, "failed smoke keeps charge")

	var wall := make_sim(room_layout(9, 7))
	r = wall.execute_player_turn({"type": "gadget", "slot": 1, "target": Vector2i(2, 0)})
	check(not r["ok"], "smoke cannot be thrown into a wall")

	var empty := make_sim(room_layout(9, 7))
	empty.player.gadgets["smoke"] = 0
	r = empty.execute_player_turn({"type": "gadget", "slot": 1, "target": Vector2i(2, 1)})
	check(not r["ok"], "empty smoke slot fails")


func test_decoy_gadget() -> void:
	var sim := make_sim(room_layout(9, 7), {
		"guards": [{"type": "standard", "start": [5, 1], "facing": [1, 0], "waypoints": [[5, 1]]}],
	})
	var r := sim.execute_player_turn({"type": "gadget", "slot": 2, "target": Vector2i(3, 1)})
	check(r["ok"], "decoy is thrown")
	eq(int(sim.player.gadgets["decoy"]), 0, "decoy charge consumed")
	check(has_event(r["events"], "decoy"), "decoy event")
	check(has_event(r["events"], "heard"), "guard hears the decoy")
	check(sim.guards[0].state != BaseEnemy.AIState.PATROL, "guard reacts to noise")

	var far := make_sim(room_layout(9, 7))
	r = far.execute_player_turn({"type": "gadget", "slot": 2, "target": Vector2i(6, 1)})
	check(not r["ok"], "decoy beyond four cells fails")
	eq(far.turn_number, 0, "failed decoy does not consume a turn")
	r = far.execute_player_turn({"type": "gadget", "slot": 2, "target": far.player.grid_pos})
	check(not r["ok"], "decoy cannot target the player's own cell")
	r = far.execute_player_turn({"type": "gadget", "slot": 2, "target": Vector2i(2, 0)})
	check(not r["ok"], "decoy cannot target a wall")


func test_emp_gadget() -> void:
	var sim := make_sim(room_layout(9, 7, Vector2i(2, 2)), {
		"cameras": [
			{"pos": [3, 2], "initial_facing": [-1, 0], "facings": [[-1, 0]], "range": 4},
			{"pos": [7, 6], "initial_facing": [-1, 0], "facings": [[-1, 0]], "range": 4},
		],
		"turrets": [{"pos": [2, 4], "facing": [0, -1]}],
		"lasers": [{"pos": [0, 2], "dir": [1, 0]}],
		"guards": [{"type": "standard", "start": [4, 3], "facing": [1, 0], "waypoints": [[4, 3]]}],
	})
	var r := sim.execute_player_turn({"type": "gadget", "slot": 3})
	check(r["ok"], "EMP activates")
	eq(int(sim.player.gadgets["emp"]), 0, "EMP charge consumed")
	check(has_event(r["events"], "emp"), "EMP event")
	check(has_event(r["events"], "stun"), "EMP stuns nearby guard")
	eq(sim.cameras[0].emp_turns, TurnManager.EMP_TURNS - 1, "nearby camera disabled")
	eq(sim.cameras[1].emp_turns, 0, "far camera unaffected")
	eq(sim.turrets[0].emp_turns, TurnManager.EMP_TURNS - 1, "nearby turret disabled")
	eq(sim.lasers[0].emp_turns, TurnManager.EMP_TURNS - 1, "nearby laser disabled")
	eq(sim.guards[0].state, BaseEnemy.AIState.STUNNED, "nearby guard is stunned")
	check(not sim.cameras[0].is_active(sim), "disabled camera is inactive")
	check(not sim.turrets[0].is_armed(sim), "disabled turret is unarmed")
	check(not sim.lasers[0].is_firing(sim, 1), "disabled laser does not fire")

	var empty := make_sim(room_layout(9, 7))
	empty.player.gadgets["emp"] = 0
	r = empty.execute_player_turn({"type": "gadget", "slot": 3})
	check(not r["ok"], "empty EMP slot fails")


func test_cloak_gadget() -> void:
	var sim := make_sim(room_layout(9, 7, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [4, 2], "facing": [-1, 0], "waypoints": [[4, 2]]}],
	})
	var r := sim.execute_player_turn({"type": "gadget", "slot": 4})
	check(r["ok"], "cloak activates")
	eq(int(sim.player.gadgets["cloak"]), 0, "cloak charge consumed")
	check(has_event(r["events"], "cloak"), "cloak event")
	eq(sim.player.cloak_turns, 1, "cloak linger after activation turn")
	check(not sim.player_is_targetable(), "cloaked player is not targetable")
	check(not sim.alarm.is_alarm(), "cloak prevents detection on activation turn")

	wait(sim)
	eq(sim.player.cloak_turns, 0, "cloak expires after its last turn")
	check(not sim.alarm.is_alarm(), "cloak covers the second turn")
	wait(sim)
	check(sim.alarm.is_alarm(), "guard spots player after cloak expires")
	eq(sim.alarm.times_triggered, 1, "alarm triggered once")

	var early := make_sim(room_layout(9, 7, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [4, 2], "facing": [-1, 0], "waypoints": [[4, 2]]}],
	})
	early.player.cloak_turns = 2
	r = early.execute_player_turn({"type": "gadget", "slot": 4})
	check(not r["ok"], "cannot activate cloak while already cloaked")
	eq(early.turn_number, 0, "failed cloak does not consume a turn")


func test_pickups() -> void:
	var chip := make_sim(room_layout(5, 3), {
		"secondary_loot": [{"pos": [2, 1], "value": 500, "name": "Chip"}],
	})
	var r := chip.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "move onto chip")
	eq(chip.player.chips, 1, "chip counter")
	eq(chip.chips_total, 1, "total chips")
	eq(chip.player.score, 500, "chip score")
	check(chip.loot[0].collected, "chip marked collected")
	check(has_event(r["events"], "pickup"), "pickup event")

	var card := make_sim(room_layout(5, 3), {
		"items": [{"kind": "keycard", "pos": [2, 1], "color": "BLUE", "name": "Blue card"}],
	})
	card.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	arr_has(card.player.keycards, "BLUE", "keycard picked up")

	var med := make_sim(room_layout(5, 3), {
		"items": [{"kind": "medkit", "pos": [2, 1], "name": "Stim"}],
	})
	med.player.hp = 1
	med.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	eq(med.player.hp, PlayerController.MAX_HP, "medkit restores one HP")
	med.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	med.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	eq(med.player.hp, PlayerController.MAX_HP, "medkit does not overheal")

	var gold := make_sim(room_layout(5, 3, Vector2i(1, 1), Vector2i(2, 1)))
	r = gold.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "move onto gold")
	check(gold.player.has_gold, "player carries gold")
	check(gold.loot_taken, "loot taken flag")
	eq(gold.player.score, 2000, "gold score")
	check(has_event(r["events"], "pickup"), "gold pickup event")


func test_pickpocket() -> void:
	var sim := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [3, 2], "facing": [1, 0], "waypoints": [[3, 2]], "keycard": "RED"}],
	})
	var r := wait(sim)
	check(r["ok"], "wait next to guard succeeds")
	arr_has(sim.player.keycards, "RED", "keycard stolen from behind")
	eq(sim.guards[0].keycard_color, "", "guard has no keycard after theft")
	eq(int(sim.stats["pick"]), 1, "pickpocket counter")
	check(has_event(r["events"], "pickpocket"), "pickpocket event")

	var seen := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [3, 2], "facing": [-1, 0], "waypoints": [[3, 2]], "keycard": "RED"}],
	})
	r = wait(seen)
	check(not seen.player.keycards.has("RED"), "keycard not stolen while seen")
	eq(int(seen.stats["pick"]), 0, "no pickpocket counter while seen")
	check(seen.alarm.is_alarm(), "guard sees player and raises alarm")

	var chase := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [3, 2], "facing": [1, 0], "waypoints": [[3, 2]], "keycard": "RED"}],
	})
	chase.trigger_alarm(chase.player.grid_pos, "test")
	wait(chase)
	check(not chase.player.keycards.has("RED"), "keycard not stolen from chasing guard")


# ───────────────────────────── enemies & environment ─────────────────────────────

func test_guard_detection() -> void:
	var sim := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"guards": [{"type": "standard", "start": [3, 2], "facing": [-1, 0], "waypoints": [[3, 2]]}],
	})
	check(sim.is_cell_seen(sim.player.grid_pos), "player starts inside guard cone")
	var r := wait(sim)
	check(r["ok"], "wait completes")
	check(sim.alarm.is_alarm(), "red zone triggers alarm")
	eq(sim.alarm.times_triggered, 1, "alarm triggered once")
	eq(sim.guards[0].state, BaseEnemy.AIState.CHASE, "guard switches to chase")
	check(has_event(r["events"], "spotted"), "spotted event")


func test_guard_suspicion() -> void:
	var sim := make_sim(room_layout(9, 7, Vector2i(4, 1)), {
		"guards": [{"type": "standard", "start": [2, 4], "facing": [1, 0], "waypoints": [[2, 4]]}],
	})
	check(sim.is_cell_seen(sim.player.grid_pos), "player is in yellow zone")
	var r := wait(sim)
	check(r["ok"], "wait completes")
	check(not sim.alarm.is_alarm(), "yellow zone does not raise full alarm")
	eq(sim.alarm.state, AlarmManager.State.SUSPICION, "global suspicion state")
	eq(sim.alarm.times_triggered, 0, "no alarm counter")
	eq(sim.guards[0].state, BaseEnemy.AIState.SUSPICIOUS_FREEZE, "guard freezes and investigates")
	check(has_event(r["events"], "suspicious"), "suspicious event")


func test_alarm_cooldown() -> void:
	var sim := make_sim(room_layout(7, 5))
	sim.trigger_alarm(sim.player.grid_pos, "test")
	check(sim.alarm.is_alarm(), "alarm manually triggered")
	for i in range(AlarmManager.COOLDOWN_TURNS - 1):
		wait(sim)
		check(sim.alarm.is_alarm(), "alarm still active at tick %d" % (i + 1))
	var r := wait(sim)
	check(not sim.alarm.is_alarm(), "alarm resets after cooldown")
	eq(sim.alarm.state, AlarmManager.State.STEALTH, "state returns to stealth")
	check(has_event(r["events"], "alarm_off"), "alarm_off event")
	eq(sim.alarm.times_triggered, 1, "trigger counter preserved")


func test_camera_detection_and_rotation() -> void:
	var static_cam := make_sim(room_layout(9, 7, Vector2i(2, 3)), {
		"cameras": [{"pos": [5, 3], "initial_facing": [-1, 0], "facings": [[-1, 0]], "range": 5}],
	})
	var r := wait(static_cam)
	check(r["ok"], "wait completes")
	check(static_cam.alarm.is_alarm(), "camera red zone triggers alarm")
	check(has_event(r["events"], "spotted_cam"), "camera spots player")
	eq(static_cam.alarm.times_triggered, 1, "camera alarm counted")

	var rotating := make_sim(room_layout(9, 7, Vector2i(2, 3)), {
		"cameras": [{"pos": [5, 3], "initial_facing": [-1, 0], "rotation_mode": "cw_90", "period": 1, "range": 5}],
	})
	var expected := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in range(4):
		wait(rotating)
		v2(rotating.cameras[0].facing, expected[i], "camera rotates clockwise, step %d" % (i + 1))


func test_turret() -> void:
	var sim := make_sim(room_layout(9, 5, Vector2i(2, 2)), {
		"turrets": [{"pos": [6, 2], "facing": [-1, 0]}],
	})
	var turret := sim.turrets[0]
	check(not turret.is_armed(sim), "turret is asleep without alarm")
	turret.update_lock(sim)
	check(not turret.locked, "sleeping turret does not lock")
	check(turret.ray_cells.is_empty(), "sleeping turret has no ray")

	sim.trigger_alarm(sim.player.grid_pos, "test")
	turret.update_lock(sim)
	check(turret.locked, "armed turret locks onto player")
	check(not turret.ray_cells.is_empty(), "armed turret has a ray")
	turret.locked = true
	turret.step_turn(sim)
	eq(sim.player.hp, PlayerController.MAX_HP - 1, "turret shot deals one damage")
	check(has_event(sim.events, "shot"), "shot event")
	check(sim.alarm.is_alarm(), "turret shot keeps alarm active")

	var cloak_sim := make_sim(room_layout(9, 5, Vector2i(2, 2)), {
		"turrets": [{"pos": [6, 2], "facing": [-1, 0]}],
	})
	cloak_sim.trigger_alarm(cloak_sim.player.grid_pos, "test")
	cloak_sim.player.cloak_turns = 1
	cloak_sim.turrets[0].locked = true
	cloak_sim.turrets[0].step_turn(cloak_sim)
	eq(cloak_sim.player.hp, PlayerController.MAX_HP, "cloaked player is not shot")

	var climax := make_sim(room_layout(9, 5, Vector2i(2, 2)), {
		"turrets": [{"pos": [6, 2], "facing": [-1, 0], "climax": true}],
	})
	check(not climax.turrets[0].is_armed(climax), "climax turret is asleep before loot")
	climax.loot_taken = true
	check(climax.turrets[0].is_armed(climax), "climax turret activates after loot")


func test_laser() -> void:
	var sim := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"lasers": [{"pos": [4, 2], "dir": [-1, 0], "on_turns": 1, "off_turns": 1, "phase": 0}],
	})
	var laser := sim.lasers[0]
	check(laser.is_firing(sim, 0), "laser fires on phase 0")
	check(not laser.is_firing(sim, 1), "laser off on phase 1")
	check(laser.is_firing(sim, 2), "laser fires again on phase 2")
	var beam: Array[Vector2i] = laser.beam_cells(sim.grid)
	eq(beam.size(), 3, "beam length to left wall")
	v2(beam[0], Vector2i(3, 2), "beam starts in front of emitter")
	v2(beam[2], Vector2i(1, 2), "beam reaches far wall")

	var r := wait(sim)
	check(r["ok"], "first wait completes")
	check(not sim.alarm.is_alarm(), "laser is off on first turn")
	r = wait(sim)
	check(r["ok"], "second wait completes")
	check(sim.alarm.is_alarm(), "laser hit triggers alarm")
	check(has_event(r["events"], "laser_hit"), "laser_hit event")
	eq(sim.player.hp, PlayerController.MAX_HP, "laser does not deal HP damage")

	var smoked := make_sim(room_layout(7, 5, Vector2i(2, 2)), {
		"lasers": [{"pos": [4, 2], "dir": [-1, 0], "on_turns": 1, "off_turns": 1, "phase": 0}],
	})
	smoked.grid.smoke_cells[Vector2i(3, 2)] = 3
	wait(smoked)
	wait(smoked)
	check(not smoked.alarm.is_alarm(), "smoke blocks laser beam")

	var loot_laser := make_sim(room_layout(9, 5, Vector2i(2, 2)), {
		"lasers": [{"pos": [6, 2], "dir": [-1, 0], "activate_on_loot": true}],
	})
	check(not loot_laser.lasers[0].enabled, "loot laser starts disabled")
	loot_laser.on_gold_taken()
	check(loot_laser.lasers[0].enabled, "loot laser enables after gold")
	check(has_event(loot_laser.events, "climax"), "climax event")


# ───────────────────────────── game flow ─────────────────────────────

func test_victory_and_loss() -> void:
	var sim := make_sim(room_layout(5, 3, Vector2i(1, 1), Vector2i(3, 1)))
	var r := sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "move toward gold")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	check(r["ok"], "pick up gold")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	check(r["ok"], "walk back toward extraction")
	r = sim.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	check(r["ok"], "step onto extraction")
	eq(sim.result, "won", "gold + extraction wins")
	eq(sim.current_phase, TurnManager.TurnPhase.GAME_OVER_LOCKED, "game over locks phase")
	check(has_event(r["events"], "won"), "won event")
	eq(sim.get_rating(), "S", "flawless run is S rank")
	r = wait(sim)
	check(not r["ok"], "cannot act after victory")

	var no_gold := make_sim(room_layout(5, 3))
	no_gold.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	r = no_gold.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	check(r["ok"], "returning to extraction works")
	eq(no_gold.result, "", "extraction without gold is not victory")

	var alarm_block := make_sim(room_layout(5, 3))
	alarm_block.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	alarm_block.trigger_alarm(alarm_block.player.grid_pos, "test")
	r = alarm_block.execute_player_turn({"type": "move", "dir": Vector2i(-1, 0)})
	check(not r["ok"], "alarm blocks extraction movement")
	v2(alarm_block.player.grid_pos, Vector2i(2, 1), "player stays in place")
	eq(alarm_block.turn_number, 1, "blocked extraction does not consume a turn")

	var on_pad := make_sim(room_layout(5, 3))
	on_pad.player.grid_pos = Vector2i(1, 1)
	on_pad.player.has_gold = true
	on_pad.trigger_alarm(on_pad.player.grid_pos, "test")
	r = wait(on_pad)
	check(r["ok"], "wait on extraction completes")
	eq(on_pad.result, "", "alarm prevents victory on extraction")

	var dead := make_sim(room_layout(7, 5))
	dead.player.hp = 0
	r = wait(dead)
	check(r["ok"], "wait with zero HP completes turn")
	eq(dead.result, "lost", "zero HP loses the mission")
	eq(dead.current_phase, TurnManager.TurnPhase.GAME_OVER_LOCKED, "defeat locks phase")
	check(dead.fail_reason != "", "defeat reason is set")
	check(has_event(r["events"], "lost"), "lost event")
	r = wait(dead)
	check(not r["ok"], "cannot act after defeat")


func test_snapshot_undo_and_preview() -> void:
	var sim := make_sim(room_layout(9, 7), {
		"guards": [{"type": "standard", "start": [5, 3], "facing": [-1, 0], "waypoints": [[5, 3], [5, 1]], "ping_pong": true}],
	})
	wait(sim)
	var snap := sim.snapshot()
	var saved_pos: Vector2i = sim.player.grid_pos
	var saved_turn: int = sim.turn_number
	sim.player.grid_pos = Vector2i(7, 5)
	sim.alarm.trigger(Vector2i(7, 5))
	sim.turn_number = 99
	sim.restore(snap)
	v2(sim.player.grid_pos, saved_pos, "restore player position")
	eq(sim.turn_number, saved_turn, "restore turn counter")
	check(not sim.alarm.is_alarm(), "restore alarm state")

	var undo_sim := make_sim(room_layout(7, 5))
	var start: Vector2i = undo_sim.player.grid_pos
	wait(undo_sim)
	undo_sim.execute_player_turn({"type": "move", "dir": Vector2i(1, 0)})
	eq(undo_sim.turn_number, 2, "two turns played")
	check(undo_sim.undo(), "undo returns true")
	eq(undo_sim.turn_number, 1, "undo restores turn")
	v2(undo_sim.player.grid_pos, start, "undo restores player position")
	eq(undo_sim.undo_count, 1, "undo counter")
	check(undo_sim.undo(), "second undo returns true")
	eq(undo_sim.turn_number, 0, "second undo restores start")
	check(not undo_sim.undo(), "undo on empty history returns false")

	var preview_sim := make_sim(room_layout(9, 7), {
		"guards": [{"type": "standard", "start": [5, 3], "facing": [-1, 0], "waypoints": [[5, 3], [5, 1]], "ping_pong": true}],
	})
	wait(preview_sim)
	var before_turn: int = preview_sim.turn_number
	var before_pos: Vector2i = preview_sim.player.grid_pos
	var before_guard: Vector2i = preview_sim.guards[0].grid_pos
	var before_alarm: int = preview_sim.alarm.state
	var before_events: int = preview_sim.events.size()
	var pv := preview_sim.compute_preview()
	eq(preview_sim.turn_number, before_turn, "preview does not advance turn")
	v2(preview_sim.player.grid_pos, before_pos, "preview does not move player")
	v2(preview_sim.guards[0].grid_pos, before_guard, "preview does not move guard")
	eq(preview_sim.alarm.state, before_alarm, "preview does not change alarm")
	eq(preview_sim.events.size(), before_events, "preview does not add events")
	check(pv.has("guards"), "preview has guards")
	check(pv.has("cams"), "preview has cameras")
	check(pv.has("turrets"), "preview has turrets")
	check(pv.has("lasers"), "preview has lasers")
	check((pv["guards"] as Dictionary).has("guard0"), "preview contains guard state")


func test_style_and_rating() -> void:
	var sim := make_sim(room_layout(7, 5))
	sim.award_style("test", 100)
	eq(sim.combo, 1, "first style action starts combo")
	eq(sim.combo_mult(), 1, "combo multiplier 1")
	eq(sim.player.score, 100, "style points applied")
	eq(int(sim.stats["maxmult"]), 1, "max multiplier tracked")
	sim.award_style("test2", 100)
	eq(sim.combo, 2, "second style action increases combo")
	eq(sim.combo_mult(), 2, "combo multiplier 2")
	eq(sim.player.score, 300, "multiplied style points")
	eq(int(sim.stats["maxmult"]), 2, "max multiplier increases")
	sim.turn_number = 10
	sim.award_style("test3", 100)
	eq(sim.combo, 1, "combo resets after a long pause")
	eq(sim.player.score, 400, "reset combo scores x1")
	sim.combo = 8
	eq(sim.combo_mult(), 5, "combo multiplier is capped")
	sim.combo = 0
	eq(sim.combo_mult(), 1, "combo multiplier floor")

	sim.level_data = {"par_turns": 20}
	sim.turn_number = 10
	sim.alarm.times_triggered = 0
	sim.chips_total = 0
	sim.player.chips = 0
	eq(sim.get_rating(), "S", "no alarm, fast, all chips -> S")
	sim.alarm.times_triggered = 1
	sim.turn_number = 20
	sim.chips_total = 1
	sim.player.chips = 1
	eq(sim.get_rating(), "A", "one alarm, under 135% par, all chips -> A")
	sim.alarm.times_triggered = 2
	eq(sim.get_rating(), "B", "two alarms -> B")
	sim.alarm.times_triggered = 4
	eq(sim.get_rating(), "C", "four alarms -> C")
	sim.alarm.times_triggered = 1
	sim.turn_number = 28
	eq(sim.get_rating(), "B", "over par limit -> B")


# ───────────────────────────── campaign data ─────────────────────────────

func test_campaign_levels_load() -> void:
	eq(GameState.LEVEL_FILES.size(), 7, "seven campaign levels")
	for i in range(GameState.LEVEL_FILES.size()):
		var path: String = GameState.LEVEL_FILES[i]
		check(FileAccess.file_exists(path), "level file exists: %s" % path)
		var sim: TurnManager = LevelLoader.load_file(path)
		check(sim != null, "level loads: %s" % path)
		if sim == null:
			continue
		check(sim.grid.width > 0 and sim.grid.height > 0, "level %d has dimensions" % (i + 1))
		check(int(sim.level_data.get("par_turns", 0)) > 0, "level %d has par_turns" % (i + 1))
		v2(sim.player.start_grid_pos, sim.player.grid_pos, "level %d player starts at spawn" % (i + 1))
		eq(sim.grid.get_tile(sim.player.grid_pos), GridManager.TileType.EXTRACTION,
			"level %d player starts on extraction" % (i + 1))
		eq(sim.result, "", "level %d starts unfinished" % (i + 1))

		var gold_found: bool = false
		var chip_count: int = 0
		for item in sim.loot:
			check(sim.grid.is_in_bounds(item.grid_pos), "loot in bounds")
			if item.kind == "gold":
				gold_found = true
				eq(sim.grid.get_tile(item.grid_pos), GridManager.TileType.VAULT_FLOOR,
					"level %d gold is on vault floor" % (i + 1))
			elif item.kind == "chip":
				chip_count += 1
		check(gold_found, "level %d has gold" % (i + 1))
		eq(sim.chips_total, chip_count, "level %d chip total matches loot" % (i + 1))

		for guard in sim.guards:
			check(sim.grid.is_in_bounds(guard.grid_pos), "guard in bounds")
			check(guard.is_active() or not sim.grid.guard_cells.has(guard.grid_pos),
				"dormant guards do not occupy cells")
		for camera in sim.cameras:
			check(sim.grid.is_in_bounds(camera.grid_pos), "camera in bounds")
			check(not camera.facing_sequence.is_empty(), "camera has facing sequence")
		for turret in sim.turrets:
			check(sim.grid.is_in_bounds(turret.grid_pos), "turret in bounds")
			check(sim.grid.solid_entities.has(turret.grid_pos), "turret is solid")
		for laser in sim.lasers:
			check(sim.grid.is_in_bounds(laser.grid_pos), "laser in bounds")
			check(laser.facing != Vector2i.ZERO, "laser has direction")
		for sw in sim.switches:
			check(sim.grid.is_in_bounds(sw.grid_pos), "switch in bounds")
			check(sim.grid.solid_entities.has(sw.grid_pos), "switch is solid")
		for door in sim.doors:
			check(sim.grid.is_in_bounds(door.grid_pos), "door in bounds")
			eq(sim.grid.get_tile(door.grid_pos), GridManager.TileType.DOOR_CLOSED,
				"door tile is closed")
			check(sim.grid.doors.get(door.grid_pos) == door, "door is registered in grid")

		var r := wait(sim)
		check(r["ok"], "level %d accepts a wait turn" % (i + 1))
		eq(sim.turn_number, 1, "level %d turn advanced" % (i + 1))
		var pv := sim.compute_preview()
		check(pv.has("guards") and pv.has("cams") and pv.has("turrets") and pv.has("lasers"),
			"level %d preview is complete" % (i + 1))


func test_campaign_solutions_replay() -> void:
	var solver_script: GDScript = load("res://tests/solver.gd") as GDScript
	check(solver_script != null, "solver script loads")
	if solver_script == null:
		return
	# Levels 1-6 have stable strict solutions. Level 7's committed solution predates
	# the current AI rules and is tracked separately by tests/replay.gd.
	for i in range(GameState.LEVEL_FILES.size() - 1):
		var path: String = "res://tests/solutions/level_%d.txt" % (i + 1)
		check(FileAccess.file_exists(path), "solution exists: %s" % path)
		if not FileAccess.file_exists(path):
			continue
		var line: String = FileAccess.get_file_as_string(path).strip_edges()
		var sim: TurnManager = LevelLoader.load_file(GameState.LEVEL_FILES[i])
		var step: int = 0
		var ok: bool = true
		for token in line.split(" ", false):
			var action: Dictionary = solver_script.str_to_action(token)
			var r: Dictionary = sim.execute_player_turn(action)
			step += 1
			if not bool(r["ok"]):
				ok = false
				break
			if sim.result != "":
				break
		check(ok, "solution %d actions are valid (stopped at %d)" % [i + 1, step])
		eq(sim.result, "won", "solution %d wins" % (i + 1))
		eq(sim.alarm.times_triggered, 0, "solution %d is alarm-free" % (i + 1))


func test_level_loader_validation() -> void:
	var valid_room: Array = room_layout(5, 5, Vector2i(1, 1), Vector2i(3, 3))
	var ok_data: Dictionary = {
		"level_id": 99,
		"title": "Test",
		"par_turns": 20,
		"layout": valid_room,
	}
	eq(LevelLoader.validate_data(ok_data, true).size(), 0, "valid campaign data passes")

	var missing_layout: Dictionary = {"level_id": 1, "title": "Bad", "par_turns": 10}
	check(not LevelLoader.validate_data(missing_layout, false).is_empty(), "missing layout rejected")
	check(LevelLoader.build(missing_layout) == null, "build returns null on missing layout")

	var jagged: Dictionary = {"layout": ["###", "##", "###"]}
	check(not LevelLoader.validate_data(jagged, false).is_empty(), "non-rectangular layout rejected")

	var unknown_char: Dictionary = {"layout": ["###", "#?#", "###"]}
	check(not LevelLoader.validate_data(unknown_char, false).is_empty(), "unknown tile symbol rejected")

	var oob_guard: Dictionary = {
		"layout": valid_room,
		"guards": [{"start": [10, 1]}],
	}
	check(not LevelLoader.validate_data(oob_guard, false).is_empty(), "out-of-bounds guard rejected")

	var no_objectives: Dictionary = {
		"level_id": 1,
		"title": "Empty",
		"par_turns": 10,
		"layout": ["###", "#.#", "###"],
	}
	check(not LevelLoader.validate_data(no_objectives, true).is_empty(), "missing E and G rejected in campaign mode")

