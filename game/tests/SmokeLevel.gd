extends Node

## Headless smoke test for the in-level HUD. Run from the game/ directory:
##   godot --headless res://tests/SmokeLevel.tscn
## Loads level 1 into the real Level scene, drives Start / Pause / Resume /
## Delete / Retry through their button signals, and exits non-zero on the
## first failed assertion. Runs with the project's autoloads (GameState),
## which `godot --check-only` does not provide.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	GameState.pending_level_path = "res://data/levels/level_001.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var pause_button: Button = level.get_node("UI/HUD/PauseButton")
	var pause_panel: Control = level.get_node("UI/PausePanel")
	var tick_timer: Timer = level.get_node("TickTimer")
	var inventory_bar: HBoxContainer = level.get_node("UI/HUD/InventoryBar")
	var board = level.get_node("Board")

	print("Pre-start")
	# Pause doubles as the in-level menu and is the only route to Retry, so
	# unlike Start it is live from the moment the level loads.
	_check(not pause_button.disabled, "Pause enabled before Start (it is the menu)")
	_check(not pause_panel.visible, "pause panel hidden before Start")
	_check(level.get_node_or_null("UI/HUD/RetryButton") == null, "no Retry button on the HUD")
	_check(pause_button.icon != null and pause_button.text == "", "Pause is icon-only")
	_check(level.get_node("UI/HUD/StartButton").icon != null, "Start is icon-only")
	var delete_button: Button = inventory_bar.get_node_or_null("delete_mode")
	_check(delete_button != null and delete_button.toggle_mode, "Delete toggle present in inventory bar")
	_check(delete_button.icon != null and delete_button.text == "", "Delete is icon-only")
	_check(inventory_bar.get_child(0) == delete_button, "Delete is first button in bar")

	# Every button in the level is icon-led now: the same action carries the
	# same glyph in the HUD, the pause menu, the lose popup and the win
	# popup. Only the inventory tiles keep text, and only as a count.
	for path in ["UI/HUD/BackButton", "UI/IntroPanel/Center/Panel/VBox/GotItButton",
			"UI/LosePanel/Center/Panel/VBox/ButtonRow/RetryButton",
			"UI/LosePanel/Center/Panel/VBox/ButtonRow/LevelSelectButton",
			"UI/WinPanel/Center/Panel/VBox/NextButton"]:
		var b: Button = level.get_node(path)
		_check(b.icon != null and b.text == "", "%s is icon-only" % path.get_file())
		_check(b.tooltip_text != "", "%s keeps a tooltip" % path.get_file())
	# Back and the pause menu's Level Select are the same action, so they
	# must not drift onto different glyphs.
	_check(level.get_node("UI/HUD/BackButton").icon
			== level.get_node("UI/PausePanel/Center/Panel/VBox/ButtonRow/LevelSelectButton").icon,
			"Back and Level Select share one glyph")
	_check(level.get_node("UI/LosePanel/Center/Panel/VBox/ButtonRow/RetryButton").icon
			== level.get_node("UI/PausePanel/Center/Panel/VBox/ButtonRow/RetryButton").icon,
			"both Retry buttons share one glyph")

	# Tile buttons show the tile's own art; the name moves to the tooltip
	# and the label carries only the remaining count.
	for bid in board.inventory.keys():
		var tile: Button = inventory_bar.get_node("block_%s" % bid)
		_check(tile.icon == block_catalog_icon(level, bid), "%s button uses its tile art" % bid)
		_check(tile.text == "x%d" % board.inventory[bid], "%s button shows its count" % bid)
		_check(tile.tooltip_text != "", "%s button names the tile on its tooltip" % bid)

	# The pause menu must be reachable before Start, since it now holds the
	# only Retry.
	pause_button.pressed.emit()
	_check(pause_panel.visible, "pause menu opens before Start")
	for entry in [["ResumeButton", "Resume"], ["ButtonRow/RetryButton", "Retry"], ["ButtonRow/LevelSelectButton", "Level Select"]]:
		var b: Button = level.get_node("UI/PausePanel/Center/Panel/VBox/%s" % entry[0])
		_check(b.icon != null and b.text == "", "pause menu %s is icon-only" % entry[1])
		_check(b.tooltip_text == entry[1], "pause menu %s keeps a tooltip" % entry[1])
	level.get_node("UI/PausePanel/Center/Panel/VBox/ResumeButton").pressed.emit()
	_check(not pause_panel.visible, "pause menu closes again before Start")

	print("Delete mode")
	var block_ids: Array = board.inventory.keys()
	_check(block_ids.size() > 0, "level has inventory")
	var block_id: String = block_ids[0]
	var block_button: Button = inventory_bar.get_node("block_%s" % block_id)
	block_button.pressed.emit()
	_check(board.selected_block_id == block_id, "block button selects block")
	delete_button.button_pressed = true # fires toggled
	_check(level.delete_mode, "Delete toggle turns delete_mode on")
	_check(board.selected_block_id == "", "Delete deselects current block")
	# Place a block directly, then check a delete-mode tap removes it and
	# a delete-mode tap on an empty cell places nothing.
	var coord: Vector2i = _first_empty_cell(board)
	var before: int = board.inventory[block_id]
	_check(board.place_block(coord, block_id), "placed a block for the delete test")
	level._handle_tap(board.to_global(Hex.axial_to_pixel(coord)))
	_check(not board.placed_blocks.has(coord), "delete-mode tap removes the block")
	_check(board.inventory[block_id] == before, "removed block refunded")
	block_button.pressed.emit()
	_check(not level.delete_mode and not delete_button.button_pressed, "picking a block turns Delete off")
	delete_button.button_pressed = true
	level._handle_tap(board.to_global(Hex.axial_to_pixel(coord)))
	_check(not board.placed_blocks.has(coord), "delete-mode tap on empty cell places nothing")
	delete_button.button_pressed = false

	print("Pause / Resume")
	level.get_node("UI/HUD/StartButton").pressed.emit()
	_check(level.started and not tick_timer.is_stopped(), "Start runs the tick timer")
	_check(not pause_button.disabled, "Pause still enabled after Start")
	var beat_before: int = level.current_beat
	pause_button.pressed.emit()
	_check(level.paused and tick_timer.paused, "Pause holds the tick timer")
	_check(pause_panel.visible, "pause panel shown")
	_check(pause_button.disabled, "HUD Pause disabled while paused")
	for i in range(12):
		await get_tree().process_frame
	_check(level.current_beat == beat_before, "no beat advanced while paused")
	level.get_node("UI/PausePanel/Center/Panel/VBox/ResumeButton").pressed.emit()
	_check(not level.paused and not tick_timer.paused, "Resume releases the timer")
	_check(not pause_panel.visible and not pause_button.disabled, "pause panel hidden, HUD Pause re-enabled")
	await get_tree().create_timer(0.5).timeout
	_check(level.current_beat != beat_before or level._subtick_count > 0, "beats advance again after Resume")

	print("Retry clears pause")
	pause_button.pressed.emit()
	level.get_node("UI/PausePanel/Center/Panel/VBox/ButtonRow/RetryButton").pressed.emit()
	_check(not level.paused and not pause_panel.visible, "Retry from pause popup unpauses")
	_check(tick_timer.is_stopped(), "Retry stops the timer")
	_check(not pause_button.disabled, "Pause still available after Retry")
	_check(inventory_bar.get_node_or_null("delete_mode") != null, "Delete button rebuilt after Retry")

	if _failures == 0:
		print("SMOKE PASS")
	else:
		printerr("SMOKE FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func block_catalog_icon(level, block_id: String) -> Texture2D:
	var block: BlockData = level.block_catalog[block_id]
	return block.icon


func _first_empty_cell(board) -> Vector2i:
	var radius: int = board.level_data.grid_radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var c := Vector2i(q, r)
			if board.in_playable_area(c) and board.cell_terrain.get(c, board.CellState.EMPTY) == board.CellState.EMPTY \
					and not board.placed_blocks.has(c) and not board.level_data.water_sources.has(c):
				return c
	return Vector2i.ZERO
