extends Node

## Renders one frame each of the main menu, the Level Select map and a level
## in play, for sharing the app's current look. Run from game/:
##   SHOT_DIR=... godot --resolution 720x1280 res://tests/ShowcaseShots.tscn

var _dir: String = ""


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(_dir)

	# A save exists in the states worth showing, so Continue is live and the
	# map has progress on it.
	GameState.current_slot = 0
	GameState.highest_unlocked_level = 16
	GameState.completed_levels = {}
	for i in range(1, 16):
		GameState.completed_levels[i] = true
	GameState.hydro_bonus_levels = {7: true}
	GameState.debug_unlock_all = false
	GameState.save_current_slot()

	await _shot_scene("res://scenes/MainMenu.tscn", "a_main_menu")
	await _shot_scene("res://scenes/LevelSelect.tscn", "b_level_map")

	# A level mid-flow: level 7 carries a Hydro Plant, so its board shows the
	# plant as well as the ordinary terrain and the inventory bar.
	GameState.pending_level_path = "res://data/levels/level_007.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _settle(6)
	level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	await _settle(4)
	await _shot("c_level_planning")
	level.get_node("UI/HUD/StartButton").pressed.emit()
	await get_tree().create_timer(1.4).timeout
	await _shot("d_level_running")
	level.queue_free()

	print("screenshots written to ", _dir)
	get_tree().quit()


func _shot_scene(path: String, name: String) -> void:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await _settle(8)
	await _shot(name)
	scene.queue_free()
	remove_child(scene)
	await _settle(2)


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("  shot ", name)
