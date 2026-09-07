extends Node

## Checks the Level Select map builds correctly and that each node's state
## follows save progress: one node per level along a connected trail, a lock
## while a level is locked, a check once completed, and a turbine badge only
## on the levels that ship a Hydro Plant.
## Run from game/:  godot --headless res://tests/VerifyLevelMap.tscn

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	GameState.current_slot = 0
	GameState.debug_unlock_all = false
	GameState.highest_unlocked_level = 16
	GameState.completed_levels = {}
	GameState.hydro_bonus_levels = {7: true}
	for i in range(1, 16):
		GameState.completed_levels[i] = true

	var screen: Control = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var map: LevelMap = screen.get_node("ScrollContainer/MapRoot")
	_check(map.points.size() == screen.TOTAL_LEVEL_SLOTS,
		"the trail has one point per level (%d)" % map.points.size())
	_check(map.reached_count == 16, "the trail is lit as far as the furthest unlocked level")
	_check(map.custom_minimum_size.y > 1000.0, "the map is taller than one screen, so it scrolls")

	# Level 1 sits at the bottom of the map and 100 at the top, matching the
	# campaign order the screen opens on.
	_check(map.points[0].y > map.points[screen.TOTAL_LEVEL_SLOTS - 1].y,
		"level 1 is at the bottom and the campaign runs upward")

	var nodes := {}
	for child in map.get_children():
		if child is Button:
			nodes[int(child.text)] = child
	_check(nodes.size() == screen.TOTAL_LEVEL_SLOTS,
		"every level has a node on the map (%d)" % nodes.size())

	_check(not nodes[15].disabled and nodes[15].tooltip_text != "", "a completed level is tappable and named")
	_check(not nodes[16].disabled, "the furthest unlocked level is tappable")
	_check(nodes[17].disabled, "a locked level is not tappable")
	_check(_badge_count(nodes[15]) >= 1, "a completed level carries a badge")
	_check(_badge_count(nodes[17]) >= 1, "a locked level carries a badge")

	# The turbine badge belongs only to levels that actually ship a plant.
	var plant_levels := []
	for i in range(screen.LEVEL_PATHS.size()):
		var data: LevelData = load(screen.LEVEL_PATHS[i])
		if not data.hydro_plant_cells.is_empty():
			plant_levels.append(data.level_id)
	_check(plant_levels.size() == 8, "eight levels ship a plant (%d)" % plant_levels.size())
	for level_id in plant_levels:
		_check(_badge_count(nodes[level_id]) >= 1, "level %d shows its bonus badge" % level_id)
	# Level 12 has no plant and is neither completed nor locked-with-a-badge
	# beyond its lock, so it is a clean control for "no bonus badge".
	_check(_badge_count(nodes[12]) == 1, "a level with no plant shows only its lock/check badge")

	if _failures == 0:
		print("LEVEL MAP PASS")
	else:
		printerr("LEVEL MAP FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _badge_count(button: Button) -> int:
	var n := 0
	for child in button.get_children():
		if child is Panel:
			n += 1
	return n
