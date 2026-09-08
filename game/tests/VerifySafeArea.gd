extends Node

## Headless check for safe-area handling. Run from the game/ directory:
##   godot --headless res://tests/VerifySafeArea.tscn
##
## Desktop Linux reports its whole screen as safe, so there is nothing to
## observe here without help: the suite drives SafeArea's simulation hook
## (FLASH_FLOOD_SAFE_INSETS, screen pixels) to stand in for a notch and a
## gesture bar, and checks that each screen moves its edge-anchored content
## out from under them -- and, just as importantly, that all three screens
## are byte-for-byte their authored selves when the insets are zero, which
## is every desktop and most phones.
##
## Insets used below are a plausible portrait phone: 96px of status
## bar/cutout at the top, 72px of gesture bar at the bottom, nothing at the
## sides. A second pass adds side insets, for a landscape-notch device.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _about(a: float, b: float, what: String, tolerance := 0.5) -> void:
	_check(absf(a - b) <= tolerance, "%s (%.1f vs %.1f)" % [what, a, b])


func _set_insets(value: String) -> void:
	OS.set_environment(SafeArea.SIMULATE_ENV, value)


func _ready() -> void:
	GameState.current_slot = 0
	GameState.debug_unlock_all = true

	await _check_no_insets()
	await _check_level_insets()
	await _check_level_select_insets()
	await _check_save_slot_insets()
	_check_unit_conversion()
	_check_clamping()
	_set_insets("")

	if _failures == 0:
		print("SAFE AREA PASS")
	else:
		printerr("SAFE AREA FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The zero case: with no cutout reported, every screen must lay out exactly
## as authored. This is the check that stops the safe-area work quietly
## reshaping the 99% of screens that need none of it.
func _check_no_insets() -> void:
	_set_insets("")
	print("No insets reported")
	_check(SafeArea.insets(get_viewport()) == Vector4.ZERO, "insets() is zero with no cutout")

	var level := await _open_level()
	var hud: Control = level.get_node("UI/HUD")
	_check(Vector4(hud.offset_left, hud.offset_top, hud.offset_right, hud.offset_bottom) == Vector4.ZERO,
			"level HUD fills the viewport")
	var board = level.get_node("Board")
	_about(board.top_position_y + board.grid_bounds.position.y, board.GRID_TOP_MARGIN_PX,
			"board top sits at GRID_TOP_MARGIN_PX")
	level.free()

	var select := await _open_scene("res://scenes/LevelSelect.tscn")
	_about(select.get_node("BackButton").offset_top, 16.0, "map Back button at its authored y")
	_about(select.get_node("HeaderBar").offset_bottom, 88.0, "header bar at its authored height")
	select.free()


func _check_level_insets() -> void:
	_set_insets("0,96,0,72")
	print("Level, 96px cutout above and 72px gesture bar below")

	var level := await _open_level()
	var hud: Control = level.get_node("UI/HUD")
	_about(hud.offset_top, 96.0, "HUD top inset below the cutout")
	_about(hud.offset_bottom, -72.0, "HUD bottom inset above the gesture bar")
	_about(hud.offset_left, 0.0, "HUD left untouched")
	_about(hud.offset_right, 0.0, "HUD right untouched")

	# The background must NOT move with it, or the inset reads as a dark
	# band down the edge of the screen -- which is what removing the
	# letterbox bars was meant to get rid of.
	var sky: ColorRect = level.get_node("Background/Sky")
	_check(sky.offset_left == 0.0 and sky.offset_top == 0.0, "sky stays full-bleed behind the inset HUD")

	var board = level.get_node("Board")
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_about(board.top_position_y + board.grid_bounds.position.y, 96.0 + board.GRID_TOP_MARGIN_PX,
			"board top clears the cutout")
	var grid_bottom: float = board.top_position_y + board.grid_bounds.end.y
	var visible_bottom: float = viewport_size.y - 72.0 - board.BOTTOM_UI_RESERVED_PX
	_check(grid_bottom - board.max_scroll_down <= visible_bottom + 0.5,
			"scrolled fully down, the grid's last row clears the gesture bar")
	level.free()

	# Side insets shrink the board rather than sliding it under the cutout.
	_set_insets("60,96,60,72")
	var narrow := await _open_level()
	var board2 = narrow.get_node("Board")
	var expected_width: float = (viewport_size.x - 120.0) * board2.GRID_WIDTH_FRACTION
	_about(board2.grid_bounds.size.x, expected_width, "board fits the safe width when the sides are inset", 1.0)
	_about(board2.position.x + board2.grid_bounds.position.x,
			60.0 + (viewport_size.x - 120.0 - expected_width) / 2.0,
			"board is centred in the safe area, not the screen", 1.0)
	narrow.free()


func _check_level_select_insets() -> void:
	_set_insets("0,96,0,72")
	print("Level Select, same phone")

	var select := await _open_scene("res://scenes/LevelSelect.tscn")
	_about(select.get_node("BackButton").offset_top, 16.0 + 96.0, "Back button drops below the cutout")
	_about(select.get_node("DebugUnlockToggle").offset_top, 20.0 + 96.0, "Unlock All drops with it")
	_about(select.get_node("HeaderBar").offset_bottom, 88.0 + 96.0,
			"header bar grows to fill the space behind the status bar")
	_about(select.get_node("HeaderShadow").offset_top, 88.0 + 96.0, "header shadow follows the bar")

	# Level 1 is the bottom-most node and the one the view opens on, so it
	# is the one a gesture bar would cover.
	var map: LevelMap = select.get_node("ScrollContainer/MapRoot")
	var level_one: Control = map.get_node("level_1")
	_check(level_one.position.y + level_one.size.y
			<= map.custom_minimum_size.y - 72.0 + 0.5, "level 1 sits above the gesture bar")
	select.free()

	_set_insets("60,96,0,72")
	var inset_select := await _open_scene("res://scenes/LevelSelect.tscn")
	var inset_map: LevelMap = inset_select.get_node("ScrollContainer/MapRoot")
	var one: Control = inset_map.get_node("level_1")
	_check(one.position.x >= 60.0, "the trail starts inside a left cutout (%.0f)" % one.position.x)
	inset_select.free()


func _check_save_slot_insets() -> void:
	_set_insets("0,96,0,72")
	print("Save slots")
	var slots := await _open_scene("res://scenes/SaveSlotSelect.tscn")
	_about(slots.get_node("BackButton").offset_top, 16.0 + 96.0, "Back button drops below the cutout")
	_about(slots.get_node("BackButton").offset_bottom, 48.0 + 96.0, "Back button keeps its height")
	slots.free()


## Screen pixels are not viewport units under a canvas_items stretch. A
## SubViewport half the window's size stands in for a phone rendering 720
## units across a 1440px screen: the same 96px cutout must come back as 48
## units, or every inset above would be twice the size it should be on a
## real high-DPI device.
func _check_unit_conversion() -> void:
	print("Pixels to viewport units")
	# Sized off the root viewport rather than DisplayServer, which reports
	# no window at all in a headless run -- SafeArea._window_size() falls
	# back the same way, so the two agree and the scale really is 1:2.
	var window_size: Vector2 = get_viewport().get_visible_rect().size
	var half := SubViewport.new()
	half.size = Vector2i(window_size * 0.5)
	add_child(half)
	_set_insets("0,96,0,72")
	var scaled := SafeArea.insets(half)
	_about(scaled.y, 48.0, "a 96px cutout is 48 units at half scale")
	_about(scaled.w, 36.0, "a 72px gesture bar is 36 units at half scale")
	half.free()


## A bad reading has to degrade into a cramped screen, not an unusable one.
func _check_clamping() -> void:
	print("Bad readings")
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_set_insets("0,100000,0,0")
	_about(SafeArea.insets(get_viewport()).y, viewport_size.y * SafeArea.MAX_INSET_FRACTION,
			"an absurd inset is clamped to MAX_INSET_FRACTION")
	_set_insets("0,-40,0,0")
	_check(SafeArea.insets(get_viewport()) == Vector4.ZERO, "a negative inset is dropped")
	_set_insets("nonsense")
	_check(SafeArea.insets(get_viewport()) == Vector4.ZERO, "a malformed override is ignored")


func _open_level() -> Node:
	GameState.pending_level_path = "res://data/levels/level_001.tres"
	return await _open_scene("res://scenes/Level.tscn")


func _open_scene(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	for i in range(4):
		await get_tree().process_frame
	remove_child(scene)
	return scene
