extends Node

## Checks the Level Select map builds correctly and that each node's state
## follows save progress: one node per level along a connected trail, a lock
## while a level is locked, a check once completed, and a turbine badge only
## on the levels that ship a Hydro Plant. Then that the ground behind the
## trail is banded by decade (Backdrop) with a fade between bands, that the
## header bar's sky follows the band in the middle of the screen, and that
## a chapter label is outlined in the ground it sits on.
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
	GameState.par_levels = {}
	for i in range(1, 16):
		GameState.completed_levels[i] = true

	var screen: Control = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var map: LevelMap = screen.get_node("ScrollContainer/MapRoot")
	# One point per TRAIL SLOT, which since the tutorial was added is five
	# more than TOTAL_LEVEL_SLOTS -- the tutorial sits below level 1.
	_check(map.points.size() == screen.total_slots(),
		"the trail has one point per slot (%d)" % map.points.size())
	# Levels 1-15 are complete, so level 16 is the furthest unlocked -- and
	# it now sits at a slot five further along than its own number.
	_check(map.reached_count == screen.slot_of_level(16) + 1,
		"the trail is lit as far as the furthest unlocked level (%d)" % map.reached_count)
	_check(map.custom_minimum_size.y > 1000.0, "the map is taller than one screen, so it scrolls")

	# Level 1 sits at the bottom of the map and 100 at the top, matching the
	# campaign order the screen opens on.
	_check(map.points[0].y > map.points[screen.TOTAL_LEVEL_SLOTS - 1].y,
		"level 1 is at the bottom and the campaign runs upward")

	var nodes := {}
	var bonus := {}
	for child in map.get_children():
		if not (child is Button):
			continue
		var name := String(child.name)
		if name.begins_with("level_"):
			nodes[int(name.trim_prefix("level_"))] = child
		elif name.begins_with("bonus_"):
			bonus[int(name.trim_prefix("bonus_"))] = child
	_check(nodes.size() == screen.total_slots(),
		"every slot has a node on the map (%d)" % nodes.size())
	for tutorial_path in screen.TUTORIAL_PATHS:
		var tutorial: LevelData = load(tutorial_path)
		_check(nodes.has(tutorial.level_id),
			"tutorial %d has a node" % tutorial.level_id)
		if nodes.has(tutorial.level_id):
			_check(not (nodes[tutorial.level_id] as Button).disabled,
				"tutorial %d is enterable" % tutorial.level_id)

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

	# Side paths: one spur off the 8th level of every set of ten, gated on
	# that level's par rather than on merely reaching it.
	_check(bonus.size() == 10, "ten side paths, one per set of ten (%d)" % bonus.size())
	_check(map.spurs.size() == 10, "the trail draws ten spurs (%d)" % map.spurs.size())
	for gate in [8, 18, 28, 38, 48, 58, 68, 78, 88, 98]:
		_check(bonus.has(gate), "level %d forks to a side path" % gate)
	for gate in bonus.keys():
		_check(bonus[gate].disabled, "bonus node %d is not enterable yet" % gate)
	# Par is unmet in this fixture, so every spur should read as locked.
	var locked := 0
	for spur in map.spurs:
		if not spur["open"]:
			locked += 1
	_check(locked == 10, "spurs are shut until par is met (%d of 10 shut)" % locked)
	_check(bonus[8].tooltip_text.contains("par"), "a shut spur says how to open it")

	# Meeting par on level 8 opens exactly that one.
	GameState.mark_par(8)
	screen._build_map()
	await get_tree().process_frame
	var reopened := 0
	for spur in map.spurs:
		if spur["open"]:
			reopened += 1
	_check(reopened == 1, "meeting par on level 8 opens one spur (%d)" % reopened)

	print("The ground is banded by decade")
	var bands: Array[Dictionary] = map.bands
	_check(bands.size() == 2 * Backdrop.PALETTES.size(),
		"two stops per band, %d in all" % bands.size())
	var ordered := true
	for i in range(1, bands.size()):
		if bands[i]["y"] < bands[i - 1]["y"]:
			ordered = false
	_check(ordered, "the stops run top to bottom")
	_check(bands[0]["y"] == 0.0 and bands[0]["palette"] == Backdrop.PALETTES.size() - 1,
		"the top of the map is the last palette")
	_check(bands.back()["y"] == map.custom_minimum_size.y and bands.back()["palette"] == 0,
		"the bottom of the map is the meadow")
	for k in range(Backdrop.PALETTES.size()):
		var mid_level: int = k * Backdrop.DECADE + 5
		var y: float = map.points[screen.slot_of_level(mid_level)].y
		_check(map.colour_at(y, "ground") == Backdrop.PALETTES[k]["ground"],
			"level %d sits on solid '%s' ground" % [mid_level, Backdrop.PALETTES[k]["name"]])
	for edge in [[1, 0], [10, 0], [11, 1], [90, 8], [91, 9], [100, 9]]:
		var y: float = map.points[screen.slot_of_level(edge[0])].y
		_check(map.colour_at(y, "ground") == Backdrop.PALETTES[edge[1]]["ground"],
			"level %d, at the edge of its decade, still sits on solid '%s'" % [edge[0], Backdrop.PALETTES[edge[1]]["name"]])
	_check(map.colour_at(map.points[0].y, "ground") == Backdrop.PALETTES[0]["ground"],
		"the tutorial shares the meadow below level 1")
	var mid_10_11: float = (map.points[screen.slot_of_level(10)].y + map.points[screen.slot_of_level(11)].y) * 0.5
	var halfway: Color = Backdrop.PALETTES[0]["ground"].lerp(Backdrop.PALETTES[1]["ground"], 0.5)
	_check(map.colour_at(mid_10_11, "ground").is_equal_approx(halfway),
		"midway between 10 and 11 the ground is half meadow, half valley")
	_check(map.colour_at(mid_10_11, "sky").is_equal_approx(
			Backdrop.PALETTES[0]["sky"].lerp(Backdrop.PALETTES[1]["sky"], 0.5)),
		"and the sky fades the same way")

	print("One animal per band stands beside the trail")
	var animals := {}
	for child in map.get_children():
		if child.name.begins_with("animal_"):
			animals[int(child.name.trim_prefix("animal_"))] = child
	_check(animals.size() == Backdrop.PALETTES.size(), "ten animals on the map (%d)" % animals.size())
	for k in range(Backdrop.PALETTES.size()):
		if not animals.has(k):
			continue
		var group: Control = animals[k]
		var centre: Vector2 = group.position + group.size * 0.5
		var mid_slot: int = screen.slot_of_level(k * Backdrop.DECADE + 5)
		var node: Vector2 = map.points[mid_slot]
		_check(is_equal_approx(centre.y, node.y), "animal %d stands level with level %d" % [k, k * Backdrop.DECADE + 5])
		_check(centre.x > screen._map_left and centre.x < screen._map_left + screen._map_width,
			"animal %d is inside the map's width" % k)
		var map_centre: float = screen._map_left + screen._map_width * 0.5
		_check(signf(centre.x - map_centre) != signf(node.x - map_centre) or is_zero_approx(node.x - map_centre),
			"animal %d is on the far side of the trail from its node" % k)
		_check(map.colour_at(centre.y, "ground") == Backdrop.PALETTES[k]["ground"],
			"animal %d stands on its own band's ground" % k)
		var slugs: Array = Characters.CAST[k]["slugs"]
		_check(group.get_child_count() == slugs.size(), "animal %d shows %d sprite(s)" % [k, slugs.size()])
		_check(group.mouse_filter == Control.MOUSE_FILTER_IGNORE and group.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"animal %d takes no input" % k)
		var pose := 4 if k == 0 else 2 # the fixture has completed levels 1-15: band 0 done, band 1 half
		_check((group.get_child(0) as TextureRect).texture == Characters.pose_texture(slugs[0], pose),
			"animal %d is %s" % [k, "drinking, its ten levels done" if pose == 4 else "standing"])

	print("The header's sky follows the band in the middle of the screen")
	var scroll: ScrollContainer = screen.get_node("ScrollContainer")
	var header: ColorRect = screen.get_node("HeaderBar")
	for spec in [[55, 5], [5, 0], [96, 9]]:
		var node_y: float = map.points[screen.slot_of_level(spec[0])].y
		scroll.scroll_vertical = int(node_y - scroll.size.y * 0.5)
		await get_tree().process_frame
		_check(header.color == Backdrop.PALETTES[spec[1]]["sky"],
			"centred on level %d the header is the '%s' sky" % [spec[0], Backdrop.PALETTES[spec[1]]["name"]])

	print("A chapter label is outlined in its ground")
	var geyser_label: Label = null
	for child in map.get_children():
		if child is Label and (child as Label).text.contains("Geyser Country"):
			geyser_label = child
	_check(geyser_label != null, "the Geyser Country label exists")
	if geyser_label != null:
		var label_y: float = geyser_label.position.y + geyser_label.size.y * 0.5
		var expected := Backdrop.outline_for(map.colour_at(label_y, "ground"))
		_check(geyser_label.get_theme_color("font_outline_color").is_equal_approx(expected),
			"its outline is derived from the ground under it")
		_check(map.colour_at(label_y, "ground") == Backdrop.PALETTES[6]["ground"],
			"which is solid 'Geyser country' (levels 61-70)")

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
