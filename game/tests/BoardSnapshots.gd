extends Node

## Renders each covered level's board in its pre-Start state and saves a PNG.
## Pre-Start is deliberate: there is no water and nothing is animating, so
## the output is deterministic and two runs can be compared pixel for pixel.
## This is the only safety net for drawing changes -- the simulation suites
## never render, so they cannot see a visual regression.
##   SHOT_DIR=... godot --resolution 720x1280 res://tests/BoardSnapshots.tscn

## One level per terrain feature, so a change to any branch of the tile
## drawing shows up somewhere in this set.
const COVERED := {
	1: "fire, pool, source",
	7: "hydro plant, splitter",
	13: "corridor, hydro",
	20: "flat grid",
	21: "dirt / dig",
	22: "radius-50 corridor, presets, dirt",
	47: "town",
	63: "geyser",
	82: "jamboree budget, hydro",
	87: "preset blocks",
}


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://snapshots"
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.current_slot = 0
	GameState.debug_unlock_all = true
	# Freeze time. Animated tiles derive their frame from a clock advanced
	# by _process(delta); with the scale at zero that clock never moves, so
	# every tile renders its tick-zero frame and two runs are comparable.
	# Without this the snapshots drift with capture timing and the whole
	# comparison is worthless.
	Engine.time_scale = 0.0

	for n in COVERED.keys():
		GameState.pending_level_path = LevelSelect.LEVEL_PATHS[n - 1]
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
		get_viewport().get_texture().get_image().save_png("%s/level_%03d.png" % [dir, n])
		print("  snapshot level %03d  (%s)" % [n, COVERED[n]])
		level.queue_free()
		remove_child(level)
		for i in range(3):
			await get_tree().process_frame

	Engine.time_scale = 1.0
	print("snapshots written to ", dir)
	get_tree().quit()
