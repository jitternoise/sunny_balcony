extends Node

## Renders the Level Select screen under a display and saves PNGs of it in
## a few progress states, so the layout can be reviewed without a device.
##   SHOT_DIR=... godot --resolution 720x1280 res://tests/LevelSelectShots.tscn

var _dir: String = ""


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(_dir)

	GameState.current_slot = 0
	GameState.debug_unlock_all = false
	GameState.highest_unlocked_level = 1
	GameState.completed_levels = {}
	var screen: Node = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(screen)
	await _settle(8)
	await _shot("10_fresh_save")

	# Part-way through the campaign: a run of completed levels, the next one
	# unlocked, the rest still locked.
	GameState.highest_unlocked_level = 16
	for i in range(1, 16):
		GameState.completed_levels[i] = true
	screen._build_level_buttons()
	await _settle(8)
	await _shot("11_mid_campaign_bottom")

	# Scrolled up into the group headers.
	var scroll: ScrollContainer = screen.get_node("ScrollContainer")
	scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - 700)
	await _settle(4)
	await _shot("12_mid_campaign_scrolled")

	print("screenshots written to ", _dir)
	get_tree().quit()


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("  shot ", name)
