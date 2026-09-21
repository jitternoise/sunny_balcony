extends Node

## The animal at every pool changes every ten levels (Characters). Checks
## the level-to-band mapping is Backdrop's, that the cast table, the art
## directory and the generator's records agree, that every pose file is
## imported at the icons' scale, that a board holds its band's art and
## poses it by pool_fill, that the animal lives inside its own lake on
## every level of the campaign, and that the geyser kept its bar.
##
##   godot --headless res://tests/VerifyCharacters.tscn
##
## Uses save slot 99.

## Nine animals across the ten bands (the Jamboree band reuses two). Was
## off while every band pointed at the tortoise.
const DISTINCT_SLUGS_REQUIRED := true

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _svg_names() -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(Characters.DIR):
		if file.ends_with(".svg"):
			names.append(file.trim_suffix(".svg"))
	names.sort()
	return names


## The slugs tools/gen_characters.py has a record for.
func _record_slugs() -> Array[String]:
	var slugs: Array[String] = []
	var entry := RegEx.create_from_string("slug=\"([a-z_]+)\"")
	for m in entry.search_all(FileAccess.get_file_as_string("res://tools/gen_characters.py")):
		if not slugs.has(m.get_string(1)):
			slugs.append(m.get_string(1))
	slugs.sort()
	return slugs


func _cast_slugs() -> Array[String]:
	var slugs: Array[String] = []
	for entry in Characters.CAST:
		for slug: String in entry["slugs"]:
			if not slugs.has(slug):
				slugs.append(slug)
	slugs.sort()
	return slugs


func _open(path: String) -> Node:
	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	for i in range(4):
		await get_tree().process_frame
	return level


## A bare board set up on a level's data, for geometry that needs no scene.
func _board_for(path: String) -> HexBoard:
	var board := HexBoard.new()
	add_child(board)
	board.setup(load(path), FFSim.load_block_catalog())
	return board


func _mean_top_x(board: HexBoard, anchor: Vector2i) -> float:
	var x := 0.0
	var cells: Array[Vector2i] = board._lake_top_cells(anchor)
	for cell in cells:
		x += Hex.axial_to_pixel(cell).x
	return x / cells.size()


func _ready() -> void:
	GameState.current_slot = 99

	print("Which animal a level gets")
	for pair in [[1, 0], [10, 0], [11, 1], [20, 1], [50, 4], [51, 5], [91, 9], [100, 9]]:
		_check(Characters.index_for_level(pair[0]) == pair[1],
			"level %d uses band %d" % [pair[0], pair[1]])
	for id in [GameState.TUTORIAL_ID_FIRST, GameState.TUTORIAL_ID_FIRST + 4, 0, 101, GameState.BONUS_ID_FIRST]:
		_check(Characters.for_level(id) == Characters.CAST[0],
			"id %d (not a campaign level) gets the first band's animal" % id)
	var same_band := true
	for n in range(1, 101):
		if Characters.index_for_level(n) != Backdrop.index_for_level(n):
			same_band = false
	_check(same_band, "every campaign level's animal band is its backdrop band")

	print("Ten bands, five poses, one file each")
	_check(Characters.CAST.size() == Backdrop.PALETTES.size(),
		"one cast entry per palette (%d)" % Characters.CAST.size())
	_check(Characters.POSES == HexBoard.POOL_BEATS_REQUIRED + 1,
		"one pose per pool_fill value, 0..%d" % HexBoard.POOL_BEATS_REQUIRED)
	for i in range(Characters.CAST.size()):
		var entry: Dictionary = Characters.CAST[i]
		var name: String = entry["name"]
		_check(name != "", "band %d has a name" % i)
		for j in range(i):
			_check(name != Characters.CAST[j]["name"], "band %d '%s' is not band %d's animal" % [i, name, j])
		var slugs: Array = entry["slugs"]
		_check(slugs.size() == (2 if i == 8 else 1),
			"band %d '%s' has %d animal(s) at the pool" % [i, name, 2 if i == 8 else 1])
		for slug: String in slugs:
			_check(slug != "" and slug == slug.to_lower(), "band %d's slug '%s' is a lowercase file stem" % [i, slug])
	var cast := _cast_slugs()
	var expected_files: Array[String] = []
	for slug in cast:
		for pose in range(Characters.POSES):
			expected_files.append("%s_%d" % [slug, pose])
	expected_files.sort()
	_check(_svg_names() == expected_files,
		"every pose has a file and every file a pose (files: %s)" % ", ".join(_svg_names()))
	_check(_record_slugs() == cast,
		"tools/gen_characters.py draws exactly the cast (%s)" % ", ".join(_record_slugs()))
	if DISTINCT_SLUGS_REQUIRED:
		_check(cast.size() == 9, "nine distinct animals across the ten bands (%d)" % cast.size())
	for slug in cast:
		for pose in range(Characters.POSES):
			var path := Characters.pose_path(slug, pose)
			_check(FileAccess.get_file_as_string(path + ".import").contains("svg/scale=3.0"),
				"%s_%d.import says svg/scale=3.0 (the icons' scale; 1.0 is a blurry 100 px)" % [slug, pose])
			var texture: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			_check(texture != null, "%s_%d loads as a texture" % [slug, pose])
			if texture != null:
				_check(texture.get_width() == 300 and texture.get_height() == 300,
					"%s_%d is 300x300 as imported (%dx%d)" % [slug, pose, texture.get_width(), texture.get_height()])
			_check(Characters.pose_texture(slug, pose) == Characters.pose_texture(slug, pose),
				"%s_%d is loaded once and cached" % [slug, pose])
	_check(Characters.pose_texture("nobody", 0) == null, "a missing animal is null, not a crash")

	print("Pose follows the lake")
	var one: Node = await _open("res://data/levels/level_001.tres")
	var board: HexBoard = one.board
	var anchor: Vector2i = board.pool_fill.keys()[0]
	for k in range(Characters.POSES):
		board.pool_fill[anchor] = k
		_check(board.character_pose_for(anchor) == k, "pool_fill %d is pose %d" % [k, k])
	board.pool_fill[anchor] = 7
	_check(board.character_pose_for(anchor) == Characters.POSES - 1, "a pool_fill past full still drinks")
	_check(board._character_poses.size() == 1 and board._character_poses[0].size() == Characters.POSES,
		"level 1's board holds one animal with %d poses" % Characters.POSES)
	for k in range(Characters.POSES):
		_check(board._character_poses[0][k] == Characters.pose_texture(Characters.CAST[0]["slugs"][0], k),
			"pose %d is the first band's animal" % k)
	one.free()

	print("The animal lives in its own lake")
	for spec in [["tutorial_1", 0], ["level_001", 0], ["level_011", 1], ["level_047", 4],
			["level_055", 5], ["level_085", 8], ["level_100", 9]]:
		var name: String = spec[0]
		var band: int = spec[1]
		var b := _board_for("res://data/levels/%s.tres" % name)
		var slugs: Array = Characters.CAST[band]["slugs"]
		_check(b._character_poses.size() == slugs.size(), "%s holds band %d's %d animal(s)" % [name, band, slugs.size()])
		for slot in range(slugs.size()):
			_check(b._character_poses[slot][2] == Characters.pose_texture(slugs[slot], 2),
				"%s slot %d standing is %s" % [name, slot, slugs[slot]])
		for lake in b.pool_fill.keys():
			var bounds: Rect2 = b._lake_bounds(lake)
			var rect: Rect2 = b.character_rect(lake, 0, slugs.size())
			var feet: float = rect.end.y - rect.size.y * (1.0 - HexBoard.CHARACTER_BASELINE)
			_check(is_equal_approx(feet, bounds.position.y + HexBoard.CHARACTER_BED_DEPTH * Hex.SIZE),
				"%s lake %s: the feet are %.2f Hex.SIZE below the lake's top" % [name, lake, HexBoard.CHARACTER_BED_DEPTH])
			var side: float = Hex.SIZE * HexBoard.CHARACTER_SCALE * (HexBoard.CHARACTER_PAIR_SCALE if slugs.size() > 1 else 1.0)
			_check(is_equal_approx(rect.size.x, side) and is_equal_approx(rect.size.y, side),
				"%s lake %s: the sprite is %.2f Hex.SIZE square" % [name, lake, side / Hex.SIZE])
			if slugs.size() == 1:
				_check(is_equal_approx(rect.get_center().x, _mean_top_x(b, lake)),
					"%s lake %s: centred over the lake's top cells" % [name, lake])
			else:
				var right: Rect2 = b.character_rect(lake, 1, slugs.size())
				_check(not rect.intersects(right) and is_equal_approx(rect.position.y, right.position.y),
					"%s lake %s: the pair stand side by side" % [name, lake])
				_check(is_equal_approx((rect.get_center().x + right.get_center().x) / 2.0, _mean_top_x(b, lake)),
					"%s lake %s: the pair are centred over the lake's top cells" % [name, lake])
		if name == "level_055":
			var lake: Vector2i = b.pool_fill.keys()[0]
			var top_cell: Vector2i = b._lake_top_cells(lake)[0]
			_check(is_equal_approx(b._lake_bounds(lake).position.y, Hex.axial_to_pixel(top_cell).y - Hex.SIZE * sqrt(3.0) / 2.0),
				"level 55 (flat grid): the lake's top is the top cell's flat edge, not a vertex")
		b.free()
	var inside := 0
	var lakes := 0
	for path in LevelSelect.campaign_paths():
		var b := _board_for(path)
		for lake in b.pool_fill.keys():
			lakes += 1
			var bounds: Rect2 = b._lake_bounds(lake)
			var rect: Rect2 = b.character_rect(lake, 0, 1)
			# Where the animal's feet touch: the middle of the art's baseline.
			var feet := Vector2(rect.get_center().x, rect.end.y - rect.size.y * (1.0 - HexBoard.CHARACTER_BASELINE))
			var in_a_top_cell := false
			for cell in b._lake_top_cells(lake):
				if Hex.axial_to_pixel(cell).distance_to(feet) <= Hex.SIZE:
					in_a_top_cell = true
			if bounds.has_point(feet) and in_a_top_cell:
				inside += 1
			else:
				printerr("    ", path, " lake ", lake, ": the animal's feet ", feet, " are not in a top cell")
		b.free()
	_check(inside == lakes, "on every campaign level the animal stands in a top cell of its lake (%d/%d)" % [inside, lakes])

	print("The geyser still has its bar")
	var bare := HexBoard.new()
	_check(bare.has_method("_draw_status_bar") and not bare.has_method("_draw_pool_status_bar"),
		"a pool draws an animal; the geyser's box bar remains")
	bare.free()

	if _failures == 0:
		print("CHARACTERS PASS")
	else:
		printerr("CHARACTERS FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
