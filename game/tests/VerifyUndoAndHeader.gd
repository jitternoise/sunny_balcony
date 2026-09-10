extends Node

## Two unrelated fixes that are both cheap to regress. From the game/ dir:
##   godot --headless res://tests/VerifyUndoAndHeader.tscn
##
## 1. Cancelling a placement that is still QUEUED. Post-Start a placement sits
##    in pending_placements until the next PLACEMENT beat, so for up to a full
##    measure the block exists only as the ghost _draw_cell() paints. The tap
##    handler tested placed_blocks alone, so the undo affordance was dead for
##    exactly the second in which a player notices the mistake.
##
## 2. Level Select's HeaderBar is screen chrome drawn OVER the scrolling map,
##    not a sibling that pushes it down, so MAP_MARGIN_TOP has to clear it by
##    hand. It didn't: the top node's edge and half its badge sat behind the
##    bar. Measured here from real node rects rather than from the constants,
##    so changing NODE_SIZE, BADGE_SIZE or the bar's height re-checks itself.
##
## Uses a scratch save slot, not slot 0 -- see the warning in CLAUDE.md.

const TEST_SLOT := 97

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _tap(level: Node, board: HexBoard, coord: Vector2i) -> void:
	level._handle_tap(board.to_global(Hex.axial_to_pixel(coord)))


func _ready() -> void:
	GameState.load_slot(TEST_SLOT)
	GameState.debug_unlock_all = true

	print("Cancelling a queued placement")
	GameState.pending_level_path = "res://data/levels/level_001.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	for i in range(6):
		await get_tree().process_frame
	level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	await get_tree().process_frame

	var board: HexBoard = level.get_node("Board")
	var block_id: String = board.level_data.starting_inventory.keys()[0]
	board.selected_block_id = block_id
	var stock: int = board.inventory.get(block_id, 0)
	_check(stock > 0, "the level ships stock of %s (precondition)" % block_id)

	# Start, so placements queue rather than landing immediately.
	level._on_start_pressed()
	_check(board.started, "the level has started (precondition)")

	# Find an empty, placeable cell.
	var target := Vector2i(0, 0)
	for c in board._playable_cells:
		if not board.placed_blocks.has(c) and not board.block_anchors.has(c) \
				and board.cell_terrain.get(c, "empty") == "empty":
			target = c
			break

	_tap(level, board, target)
	_check(board.pending_placements.has(target),
		"the tap queues a placement (it is not on the board yet)")
	_check(not board.placed_blocks.has(target),
		"...and placed_blocks is still empty there (precondition)")
	_check(board.inventory.get(block_id, 0) == stock - 1,
		"the block was taken from inventory at queue time")

	# The fix: a second tap on the ghost cancels it, without waiting a measure.
	_tap(level, board, target)
	_check(not board.pending_placements.has(target),
		"a second tap cancels the queued placement")
	_check(not board.block_anchors.has(target), "and releases the cell")
	_check(board.inventory.get(block_id, 0) == stock,
		"and refunds it exactly once (%d back to %d)"
			% [stock - 1, board.inventory.get(block_id, 0)])

	print("Tapping an empty cell still places, it is not swallowed")
	# The regression risk of widening that condition: a stale anchor would
	# make an empty cell eat taps forever.
	_tap(level, board, target)
	_check(board.pending_placements.has(target), "the cell still accepts a placement")
	_tap(level, board, target)

	level.queue_free()
	remove_child(level)
	await get_tree().process_frame

	print("Level Select's header does not clip the top node")
	# Complete the last level so its node carries a check badge. Without one
	# the top node has no children at all and this check measures only the
	# node's own edge -- missing the badge overhang, which is the part that
	# was actually being clipped. In-memory only; no save is written.
	GameState.completed_levels[100] = true
	var select: Node = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(select)
	for i in range(8):
		await get_tree().process_frame
	var header: ColorRect = select.get_node("HeaderBar")
	var map_root: Control = select.get_node("ScrollContainer/MapRoot")
	var scroll: ScrollContainer = select.get_node("ScrollContainer")

	# The topmost node is the highest-numbered slot: smallest y in map space.
	var top_node: Control = null
	for c in map_root.get_children():
		if c is Control and (c.name.begins_with("level_") or c.name.begins_with("slot_")):
			if top_node == null or (c as Control).position.y < top_node.position.y:
				top_node = c
	_check(top_node != null, "found the topmost map node (%s)"
		% (top_node.name if top_node else "none"))
	_check(top_node.get_child_count() > 0,
		"...and it carries a badge, so the overhang is really being measured")

	# Its badge overhangs upward, so measure the union of node and children.
	var top_edge: float = top_node.position.y
	for child in top_node.get_children():
		if child is Control:
			top_edge = minf(top_edge, top_node.position.y + (child as Control).position.y)

	# Convert to screen space: scrolled to the very top, map y == screen y.
	scroll.scroll_vertical = 0
	await get_tree().process_frame
	var on_screen: float = top_edge - scroll.scroll_vertical
	_check(on_screen >= header.size.y,
		"its topmost pixel (y=%.0f) clears the %.0f-tall header bar"
			% [on_screen, header.size.y])

	select.queue_free()
	remove_child(select)
	await get_tree().process_frame
	GameState.delete_slot(TEST_SLOT)

	if _failures == 0:
		print("UNDO AND HEADER PASS")
	else:
		printerr("UNDO AND HEADER FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
