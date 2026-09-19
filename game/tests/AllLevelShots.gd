extends Node
## Review aid: render EVERY level (tutorial + 1-100) pre-Start to PNG.
##   SHOT_DIR=... [ONLY=level_001,level_047] godot --resolution 720x1280 res://tests/AllLevelShots.tscn
## Writes nothing to a real save: uses slot 99 like VerifySaveIntegrity.

func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://allshots"
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.current_slot = 99
	GameState.debug_unlock_all = true
	Engine.time_scale = 0.0
	# ONLY="tutorial_1,level_047" renders just those files; unset renders all.
	var only := OS.get_environment("ONLY").split(",", false)
	var paths := LevelSelect.campaign_paths()
	for idx in range(paths.size()):
		var path: String = paths[idx]
		if only.size() > 0 and not only.has(path.get_file().get_basename()):
			continue
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
		await RenderingServer.frame_post_draw
		var name := path.get_file().get_basename()
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
		print("  shot ", name)
		level.queue_free()
		remove_child(level)
		for i in range(3):
			await get_tree().process_frame
	Engine.time_scale = 1.0
	print("shots written to ", dir)
	get_tree().quit()
