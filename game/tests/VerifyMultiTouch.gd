extends Node

## Headless check that the board is a single-pointer surface. Run from game/:
##   godot --headless res://tests/VerifyMultiTouch.tscn
##
## Phones are multi-touch and the board is not. The press state
## (_press_pos, _drag_active, the catapult sequence) only ever described ONE
## press, but nothing enforced that, and a second contact is not exotic: it
## is the thumb of the hand holding the phone brushing the glass while the
## index finger scrolls one of the 38 levels taller than the screen.
##
## The sequences below are written as finger scripts -- (index, position,
## down/up) -- because that is the only way these bugs reproduce. Each one
## is a thing a hand actually does, not a synthetic edge case.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _touch(level: Node, index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	level._unhandled_input(e)


func _drag(level: Node, index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	level._unhandled_input(e)


func _open(path: String) -> Node:
	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var intro: Control = level.get_node("UI/IntroPanel")
	if intro.visible:
		level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	await get_tree().process_frame
	return level


func _close(level: Node) -> void:
	level.queue_free()
	remove_child(level)
	await get_tree().process_frame


func _ready() -> void:
	GameState.current_slot = 0
	GameState.debug_unlock_all = true

	# Level 1 fits the screen; a block is selected so a tap would place one,
	# which is what makes an unwanted tap observable.
	var level := await _open("res://data/levels/level_001.tres")
	var board = level.get_node("Board")
	board.selected_block_id = board.level_data.starting_inventory.keys()[0]
	var p := Vector2(360.0, 460.0)

	print("An unmatched touch-up does nothing")
	var before: int = board.placed_blocks.size()
	_touch(level, 0, p, false) # finger up with no press ever recorded
	_check(board.placed_blocks.size() == before,
		"a lone touch-up places no block")
	_check(level._last_tap_coord != board.screen_to_hex(board.to_local(p))
			or before == board.placed_blocks.size(),
		"...and does not run the tap path")

	print("A second finger cannot steal a press")
	level._press_active = false
	_touch(level, 0, p, true)                       # finger 0 presses
	var owner_pos: Vector2 = level._press_pos
	_touch(level, 1, Vector2(120.0, 900.0), true)   # thumb brushes the glass
	_check(level._press_pos == owner_pos,
		"the second finger does not move the press origin")

	print("The intruding finger's release is ignored")
	before = board.placed_blocks.size()
	# Watch the tap path itself, not just the block count: the thumb lifts
	# over a cell that may be unplaceable anyway, so an unchanged inventory
	# would prove nothing. _last_tap_coord is written by _handle_tap() and
	# by nothing else, so it is a direct readout of "did the tap run".
	var tap_before: Vector2i = level._last_tap_coord
	_touch(level, 1, Vector2(120.0, 900.0), false)  # thumb lifts
	_check(level._last_tap_coord == tap_before,
		"the thumb lifting never reaches the tap path")
	_check(board.placed_blocks.size() == before,
		"the thumb lifting places no block")
	_check(level._press_active, "and finger 0's press is still live")

	print("The owning finger still works normally")
	_touch(level, 0, p, false)
	_check(board.placed_blocks.size() == before + 1,
		"finger 0's release places its block")
	await _close(level)

	# A tall level, so there is something to scroll.
	print("A second finger cannot hijack a scroll")
	level = await _open("res://data/levels/level_013.tres")
	board = level.get_node("Board")
	_check(board.max_scroll_down > 0.0, "level 13 scrolls (precondition)")
	var y0: float = board.position.y
	_touch(level, 0, Vector2(360.0, 700.0), true)
	_drag(level, 0, Vector2(360.0, 660.0), Vector2(0.0, -40.0))
	var after_own: float = board.position.y
	_check(after_own != y0, "finger 0's drag scrolls the board")
	_drag(level, 1, Vector2(200.0, 300.0), Vector2(0.0, -80.0))
	_check(board.position.y == after_own,
		"a second finger's drag does not scroll")
	before = board.placed_blocks.size()
	_touch(level, 1, Vector2(200.0, 300.0), false)
	_check(board.placed_blocks.size() == before,
		"nor does its release place a block mid-scroll")
	_touch(level, 0, Vector2(360.0, 660.0), false)
	_check(board.placed_blocks.size() == before,
		"and the scrolling finger's own release is still a scroll, not a tap")
	await _close(level)

	print("A release after a background pause is ignored")
	level = await _open("res://data/levels/level_001.tres")
	board = level.get_node("Board")
	board.selected_block_id = board.level_data.starting_inventory.keys()[0]
	_touch(level, 0, p, true)
	level.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	before = board.placed_blocks.size()
	_touch(level, 0, p, false) # the finger the player was holding when the call came
	_check(board.placed_blocks.size() == before,
		"coming back from a call does not place the block under the finger")
	await _close(level)

	if _failures == 0:
		print("MULTITOUCH PASS")
	else:
		printerr("MULTITOUCH FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
