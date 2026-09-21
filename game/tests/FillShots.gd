extends Node
## Review aid: snapshots one level at several pool-fill states by stepping
## the board's beat phases directly (deterministic, no timer).
##   LEVEL=res://data/levels/tutorial_2.tres SHOT_DIR=... godot --resolution 720x1280 res://tests/FillShots.tscn
##
## That only fills a pool the natural fall reaches (tutorial 2's); nothing
## is placed or dug, so on a campaign level the water misses the lake and
## every shot is pose 0. POSES=1 instead sets every lake's pool_fill to
## 0..4 in turn and shoots p0..p4.png -- the pose is pure state, so the
## animal at every pool can be reviewed on any level without a solution.
##   POSES=1 LEVEL=res://data/levels/level_001.tres SHOT_DIR=... godot --resolution 720x1280 res://tests/FillShots.tscn

func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	var path := OS.get_environment("LEVEL")
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.current_slot = 99
	GameState.debug_unlock_all = true
	Engine.time_scale = 0.0
	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	for i in range(8):
		await get_tree().process_frame
	var intro: Control = level.get_node("UI/IntroPanel")
	if intro.visible:
		level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	for i in range(6):
		await get_tree().process_frame
	var board: HexBoard = level.board
	if OS.get_environment("POSES") != "":
		for pose in range(HexBoard.POOL_BEATS_REQUIRED + 1):
			for anchor in board.pool_fill.keys():
				board.pool_fill[anchor] = pose
			board.queue_redraw()
			for i in range(3):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/p%d.png" % [dir, pose])
			print("  shot pose ", pose)
		get_tree().quit()
		return
	board.started = true
	var measure := 0
	for target in [0, 6, 7, 8, 9, 10]:
		while measure < target and not board.game_over:
			board.resolve_placement_phase()
			board.resolve_water_phase()
			board.resolve_terrain_phase()
			board.resolve_status_phase()
			measure += 1
		board.queue_redraw()
		for i in range(3):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/m%02d.png" % [dir, measure])
		print("  shot measure ", measure, " fill=", board.pool_fill)
	get_tree().quit()
