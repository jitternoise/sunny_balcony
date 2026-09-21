extends Node

## The animal at every pool changes every ten levels (Characters). Checks
## the level-to-band mapping is Backdrop's, that the cast table, the art
## directory and the generator's records agree, and that every pose file
## is imported at the icons' scale.
##
##   godot --headless res://tests/VerifyCharacters.tscn
##
## Uses save slot 99.

## Flip on once every band has its own art (S6 of the plan): until then
## every band points at the tortoise and the cast is deliberately not
## distinct.
const DISTINCT_SLUGS_REQUIRED := false

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

	if _failures == 0:
		print("CHARACTERS PASS")
	else:
		printerr("CHARACTERS FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
