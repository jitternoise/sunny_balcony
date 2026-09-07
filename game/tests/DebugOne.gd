extends Node

func _ready() -> void:
	var catalog := LevelSim.load_block_catalog()
	var data: LevelData = load("res://data/levels/level_001.tres")
	print("sources=", data.water_sources, " fires=", data.fire_cells, " pools=", data.pool_targets)
	var board := HexBoard.new()
	add_child(board)
	board.setup(data, catalog)
	print("after setup: fires_remaining=", board.fires_remaining, " pool_fill=", board.pool_fill,
		" water_cells=", board.water_cells.size(), " inventory=", board.inventory)
	print("place wall(-1,-3) ->", board.place_block(Vector2i(-1, -3), "wall"))
	board.started = true
	for m in range(12):
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		var coords: Array = []
		for e in board.water_cells:
			coords.append(e["coord"])
		print("m%d water=%s fires=%d pools=%s over=%s reason=%s"
			% [m + 1, coords, board.fires_remaining, board.pool_fill, board.game_over, board.lose_reason])
		if board.game_over:
			break
	get_tree().quit()
