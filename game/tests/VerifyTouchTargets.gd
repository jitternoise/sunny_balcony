extends Node

## Headless check that every tappable control is big enough to hit. From game/:
##   godot --headless res://tests/VerifyTouchTargets.tscn
##
## Under stretch/aspect=expand the 720-unit-wide viewport maps onto the whole
## device width, so one viewport unit is 0.5dp on a 360dp phone (the narrow
## end of the mainstream range) and 0.57dp on a 411dp one. Android's minimum
## touch target is 48dp and Apple's is 44pt, so a control needs >=96 units to
## clear both on a 360dp phone.
##
## Before this was enforced the HUD's Start/Pause/Back were 56 units (28dp),
## the main menu's three buttons ~47 (24dp), and the save-slot screen's Back
## button 32 units -- 16dp, a third of the minimum, on the screen that picks
## which save to load.
##
## Measured from the live scene rather than read off the .tscn, so a theme
## change, a container that squeezes a child, or a font swap is caught too.

const MIN_UNITS := 96.0
const NARROW_PHONE_DP := 360.0
const DESIGN_WIDTH := 720.0

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _dp(units: float) -> float:
	return units * (NARROW_PHONE_DP / DESIGN_WIDTH)


## Every Button under `root` that a player can actually press right now.
func _buttons(root: Node) -> Array:
	var out := []
	for b in root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled:
			out.append(b)
	return out


func _measure(root: Node, label: String, skip: Array = []) -> void:
	var checked := 0
	for b in _buttons(root):
		if skip.has(b.name):
			continue
		checked += 1
		var s: Vector2 = b.size
		var small: float = minf(s.x, s.y)
		_check(small >= MIN_UNITS - 0.5, "%s / %s is %.0fx%.0f units (%.0fdp shortest side)"
			% [label, b.name, s.x, s.y, _dp(small)])
	_check(checked > 0, "%s: found buttons to measure" % label)


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	for i in range(6):
		await get_tree().process_frame
	return scene


func _ready() -> void:
	GameState.current_slot = 0
	GameState.debug_unlock_all = true

	print("Main menu")
	var menu := await _open("res://scenes/MainMenu.tscn")
	_measure(menu, "MainMenu")
	menu.queue_free()
	remove_child(menu)
	await get_tree().process_frame

	print("Save slot select")
	var slots := await _open("res://scenes/SaveSlotSelect.tscn")
	_measure(slots, "SaveSlotSelect")
	slots.queue_free()
	remove_child(slots)
	await get_tree().process_frame

	print("In level -- HUD and inventory bar")
	# Level 19 is the densest HUD case: the budget label is visible and the
	# inventory bar carries every block type at once.
	GameState.pending_level_path = "res://data/levels/level_019.tres"
	var level := await _open("res://scenes/Level.tscn")
	level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	for i in range(4):
		await get_tree().process_frame
	_measure(level, "Level")

	print("In level -- the pause menu")
	level._on_pause_pressed()
	for i in range(4):
		await get_tree().process_frame
	_measure(level, "Paused")

	print("The inventory bar still fits its row")
	# Widening the Delete toggle to a real touch target eats into a row that
	# already has to hold every block type on a jamboree level. If the
	# children stop fitting, an HBoxContainer does not shrink past their
	# minimums -- it overflows, and the last button leaves the screen.
	var bar: HBoxContainer = level.get_node("UI/HUD/InventoryBar")
	var used := 0.0
	var kids := 0
	for c in bar.get_children():
		if c is Control and c.visible:
			used += (c as Control).size.x
			kids += 1
	used += bar.get_theme_constant("separation") * maxf(kids - 1, 0)
	_check(used <= bar.size.x + 0.5,
		"level 19's %d buttons use %.0f of %.0f units" % [kids, used, bar.size.x])

	print("The board still has room to live in")
	var board: HexBoard = level.get_node("Board")
	var vp: float = get_viewport().get_visible_rect().size.y
	var available: float = vp - HexBoard.GRID_TOP_MARGIN_PX - HexBoard.BOTTOM_UI_RESERVED_PX
	_check(available > vp * 0.6,
		"the grid band is %.0f of %.0f units (%.0f%%)" % [available, vp, 100.0 * available / vp])
	_check(board.top_position_y > 0.0, "the grid still starts below the HUD row")

	level.queue_free()
	remove_child(level)
	await get_tree().process_frame

	if _failures == 0:
		print("TOUCH TARGETS PASS")
	else:
		printerr("TOUCH TARGETS FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
