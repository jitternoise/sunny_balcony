extends Node

## Headless check that the board only animates when it can be seen. From game/:
##   godot --headless res://tests/VerifyBoardHeartbeat.tscn
##
## HexBoard._process() calls queue_redraw() 12 times a second whenever a level
## has water or an animated tile -- which is every level, since every level has
## fire. Pausing never stopped it: Level.paused only freezes tick_timer. So the
## board repainted behind opaque popups and through the whole pause menu, while
## the platform wake lock held the display at full brightness.
##
## The risk in fixing that is the opposite bug -- a board that stops animating
## and never starts again -- so every check below comes in a pair: it stops
## when covered, AND it starts again when uncovered.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _settle(n: int = 3) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	GameState.current_slot = 0
	GameState.debug_unlock_all = true
	GameState.pending_level_path = "res://data/levels/level_001.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _settle(4)

	var board: HexBoard = level.get_node("Board")
	var intro: Control = level.get_node("UI/IntroPanel")

	print("Behind the intro popup")
	_check(intro.visible, "the intro popup is up (precondition)")
	_check(not board.is_processing(), "the board does not animate behind it")

	print("Playing")
	level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	await _settle()
	_check(not intro.visible, "the intro popup is dismissed")
	_check(board.is_processing(), "the board animates once the board is visible")

	# The heartbeat must actually be ticking, not merely enabled: _process
	# accumulates delta and only redraws on a new tick, so a level with no
	# water and no animated tiles would sit still even while processing.
	var tick_before: int = board._anim_tick
	await _settle(30)
	_check(board._anim_tick != tick_before,
		"and the animation clock really is advancing")

	print("Paused")
	level._on_pause_pressed()
	await _settle()
	_check(level.paused, "the level is paused (precondition)")
	_check(not board.is_processing(), "the board stops animating while paused")
	tick_before = board._anim_tick
	await _settle(30)
	_check(board._anim_tick == tick_before, "and the animation clock is frozen")

	print("Resumed")
	level._on_resume_pressed()
	await _settle()
	_check(board.is_processing(), "the board animates again after Resume")
	tick_before = board._anim_tick
	await _settle(30)
	_check(board._anim_tick != tick_before, "and the clock is advancing again")

	print("Backgrounded (a call arrives)")
	level.notification(NOTIFICATION_APPLICATION_PAUSED)
	await _settle()
	_check(not board.is_processing(), "the board stops when the app loses the foreground")
	level._on_resume_pressed()
	await _settle()
	_check(board.is_processing(), "and starts again on the way back in")

	print("Level over")
	level._on_level_lost()
	await _settle()
	_check(level.get_node("UI/LosePanel").visible, "the lose popup is up (precondition)")
	_check(not board.is_processing(), "the board stops animating behind it")

	level.queue_free()
	remove_child(level)
	await _settle()

	if _failures == 0:
		print("BOARD HEARTBEAT PASS")
	else:
		printerr("BOARD HEARTBEAT FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
