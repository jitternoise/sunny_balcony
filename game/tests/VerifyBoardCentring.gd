extends Node

## A grid that fits on screen is centred in the band between the HUD and
## the inventory bar; one that does not is pinned to the top of that band
## and scrolls. Checked at the real portrait viewport, because the whole
## question is about vertical SIZE and --headless reports a square
## 1280x1280 where every board overflows and nothing is ever centred.
##
##   xvfb-run -a --server-args="-screen 0 720x1280x24" \
##     godot --resolution 720x1280 res://tests/VerifyBoardCentring.tscn
##
## Uses no save slot.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _open(path: String) -> Node:
	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	for i in range(6):
		await get_tree().process_frame
	return level


## The vertical band a board may occupy, in viewport coordinates.
func _band(board, inset_top: float, inset_bottom: float) -> Vector2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var top: float = inset_top + board.GRID_TOP_MARGIN_PX
	var bottom: float = vp.y - board.BOTTOM_UI_RESERVED_PX - inset_bottom
	return Vector2(top, bottom)


func _ready() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	print("viewport %s" % vp)
	_check(int(vp.x) == 720 and int(vp.y) == 1280,
		"running at the real portrait viewport (this test is meaningless headless)")
	OS.set_environment(SafeArea.SIMULATE_ENV, "")

	print("A grid that fits is centred in the band")
	for spec in [
		{"path": "res://data/levels/tutorial_1.tres", "label": "tutorial 1 (radius 3)"},
		{"path": "res://data/levels/level_001.tres", "label": "level 1 (radius 4)"},
		{"path": "res://data/levels/level_055.tres", "label": "level 55 (flat, radius 4)"},
	]:
		var level := await _open(spec["path"])
		var board = level.get_node("Board")
		var band := _band(board, 0.0, 0.0)
		var top: float = board.position.y + board.grid_bounds.position.y
		var bottom: float = board.position.y + board.grid_bounds.end.y
		_check(board.max_scroll_down == 0.0, "%s fits without scrolling" % spec["label"])
		var above: float = top - band.x
		var below: float = band.y - bottom
		_check(above >= -0.5, "%s does not rise above the HUD (%.1f)" % [spec["label"], above])
		_check(absf(above - below) <= 1.0,
			"%s is centred: %.1f above, %.1f below" % [spec["label"], above, below])
		level.free()

	print("A grid that overflows is pinned to the top and scrolls")
	var tall := await _open("res://data/levels/level_022.tres")
	var tall_board = tall.get_node("Board")
	var tall_band := _band(tall_board, 0.0, 0.0)
	var tall_top: float = tall_board.position.y + tall_board.grid_bounds.position.y
	_check(tall_board.max_scroll_down > 0.0, "level 22 needs to scroll")
	_check(absf(tall_top - tall_band.x) <= 0.5,
		"level 22 starts at the top of the band (%.1f vs %.1f)" % [tall_top, tall_band.x])
	tall.free()

	print("Centring respects a cutout and a gesture bar")
	OS.set_environment(SafeArea.SIMULATE_ENV, "0,96,0,72")
	var inset := await _open("res://data/levels/tutorial_1.tres")
	var inset_board = inset.get_node("Board")
	var inset_band := _band(inset_board, 96.0, 72.0)
	var i_top: float = inset_board.position.y + inset_board.grid_bounds.position.y
	var i_bottom: float = inset_board.position.y + inset_board.grid_bounds.end.y
	var i_above: float = i_top - inset_band.x
	var i_below: float = inset_band.y - i_bottom
	_check(i_above >= -0.5, "inset board clears the cutout")
	_check(absf(i_above - i_below) <= 1.0,
		"inset board is centred in the INSET band: %.1f above, %.1f below" % [i_above, i_below])
	inset.free()
	OS.set_environment(SafeArea.SIMULATE_ENV, "")

	if _failures == 0:
		print("BOARD CENTRING PASS")
	else:
		printerr("BOARD CENTRING FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
