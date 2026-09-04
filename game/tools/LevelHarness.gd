extends Node

## Headless level harness. Loads a level, runs it for a fixed number of
## beats with no player input, and reports what the simulation did. Lets a
## level be exercised without a display or a human.
##
##   godot --headless --path game res://tools/LevelHarness.tscn -- <level> [beats]
##
## <level> is a level number (24) or a res:// path. Default 40 beats.

const DEFAULT_BEATS := 40

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var which := args[0] if args.size() > 0 else "1"
	var beats := int(args[1]) if args.size() > 1 else DEFAULT_BEATS

	var path := which
	if not path.begins_with("res://"):
		path = "res://data/levels/level_%03d.tres" % int(which)

	if not ResourceLoader.exists(path):
		print("no such level: ", path)
		get_tree().quit(1)
		return

	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame

	var board = level.get_node("Board")
	var data = level.level_data
	print("=== %s (%s) ===" % [data.display_name, path.get_file()])
	print("grid_radius=%d  sources=%s  fires=%d  pools=%d" % [
		data.grid_radius, str(data.water_sources), data.fire_cells.size(),
		data.pool_targets.size()])

	# Drive the beat cycle directly rather than waiting on the real timer.
	var reached := 0
	var max_depth := -999
	for i in beats:
		level._advance_beat()
		reached = i + 1
		for w in board.water_cells:
			max_depth = maxi(max_depth, w["coord"].y)
		if board.game_over:
			break

	# Optional render capture: pass a third arg to save a PNG of the board.
	# Requires a real display (do NOT pass --headless for this).
	if args.size() > 2:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(args[2])
		print("screenshot       : %s" % args[2])

	print("beats run        : %d" % reached)
	print("live water cells : %d" % board.water_cells.size())
	print("deepest row (r)  : %s" % (str(max_depth) if max_depth > -999 else "water never entered the board"))
	print("fires remaining  : %d of %d" % [board.fires_remaining, data.fire_cells.size()])
	print("game_over        : %s%s" % [board.game_over,
		("  reason=" + board.lose_reason) if board.lose_reason != "" else ""])
	get_tree().quit(0)
