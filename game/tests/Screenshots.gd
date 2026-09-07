extends Node

## Renders the real Level scene in an actual window and saves PNGs of the
## HUD states the new Pause/Delete buttons introduce. Meant to be run under
## a display (e.g. xvfb-run) from the game/ directory:
##   godot --resolution 720x1280 res://tests/Screenshots.tscn
## Output directory comes from the SHOT_DIR environment variable.

var _dir: String = ""


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(_dir)

	# Winning a level saves progress, which needs an active slot -- without
	# one _on_level_won() below pushes a "no active save slot" error that
	# has nothing to do with what is being captured.
	GameState.current_slot = 0
	GameState.hydro_bonus_levels = {}
	# Level 7 ships a Hydro Plant, so its win popup carries the bonus line.
	var level_path := OS.get_environment("LEVEL")
	if level_path == "":
		level_path = "res://data/levels/level_001.tres"
	GameState.pending_level_path = level_path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _settle()

	# Level 1 has intro text, which pops a modal over everything -- dismiss
	# it so the HUD underneath is what gets captured.
	var intro: Control = level.get_node("UI/IntroPanel")
	if intro.visible:
		await _shot("00_intro")
		level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
		await _settle()

	await _shot("01_prestart")

	# Delete mode on, with a block placed so the eraser has a target.
	var inventory_bar: HBoxContainer = level.get_node("UI/HUD/InventoryBar")
	var board = level.get_node("Board")
	var block_id: String = board.inventory.keys()[0]
	var coord: Vector2i = _first_empty_cell(board)
	board.place_block(coord, block_id)
	inventory_bar.get_node("delete_mode").button_pressed = true
	await _settle()
	await _shot("02_delete_mode_on")

	inventory_bar.get_node("delete_mode").button_pressed = false
	await _settle()

	# Start, let water actually flow a few beats, then pause.
	level.get_node("UI/HUD/StartButton").pressed.emit()
	await get_tree().create_timer(1.2).timeout
	await _shot("03_running")
	level.get_node("UI/HUD/PauseButton").pressed.emit()
	await _settle()
	await _shot("04_paused")

	level.get_node("UI/PausePanel/Center/Panel/VBox/ResumeButton").pressed.emit()
	await get_tree().create_timer(0.8).timeout
	await _shot("05_resumed")

	# The win and lose popups are driven straight off their handlers rather
	# than by playing the level out, so both panels can be eyeballed.
	level._on_level_lost()
	await _settle()
	await _shot("06_lost")
	level.get_node("UI/LosePanel").visible = false
	level._on_level_won()
	await _settle()
	await _shot("07_won")

	print("screenshots written to ", _dir)
	get_tree().quit()


func _settle() -> void:
	for i in range(4):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, name])
	print("  shot ", name)


func _first_empty_cell(board) -> Vector2i:
	var radius: int = board.level_data.grid_radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var c := Vector2i(q, r)
			if board.in_playable_area(c) and board.cell_terrain.get(c, board.CellState.EMPTY) == board.CellState.EMPTY \
					and not board.placed_blocks.has(c) and not board.level_data.water_sources.has(c):
				return c
	return Vector2i.ZERO
