extends Node

## The sky and ground behind a level change every ten levels (Backdrop).
## Checks the level-to-palette mapping, that the ten pairs are distinct
## and keep the board readable, that the HUD outline derived from each
## ground is as dark as the old fixed green, and that a level actually
## paints its band's colours -- with Level.tscn's authored colours still
## being the first palette.
##
##   godot --headless res://tests/VerifyBackdrops.tscn
##
## Uses save slot 99.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


## Colours in a .tscn are written to four decimals, so "the same colour"
## is per-channel agreement to a thousandth, not is_equal_approx().
func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 \
		and absf(a.b - b.b) < 0.001 and absf(a.a - b.a) < 0.001


func _open(path: String) -> Node:
	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	for i in range(4):
		await get_tree().process_frame
	return level


func _ready() -> void:
	GameState.current_slot = 99

	print("Which palette a level gets")
	for pair in [[1, 0], [10, 0], [11, 1], [20, 1], [50, 4], [51, 5], [91, 9], [100, 9]]:
		_check(Backdrop.index_for_level(pair[0]) == pair[1],
			"level %d uses palette %d" % [pair[0], pair[1]])
	for id in [GameState.TUTORIAL_ID_FIRST, GameState.TUTORIAL_ID_FIRST + 4, 0, 101, GameState.BONUS_ID_FIRST]:
		_check(Backdrop.index_for_level(id) == 0, "id %d (not a campaign level) uses the meadow" % id)

	print("Ten distinct pairs that keep the board readable")
	_check(Backdrop.PALETTES.size() == 10, "there are ten palettes")
	var empty_luma: float = HexBoard.TILE_VISUALS[HexBoard.TILE_EMPTY]["fill"].get_luminance()
	for i in range(Backdrop.PALETTES.size()):
		var p: Dictionary = Backdrop.PALETTES[i]
		var name: String = p["name"]
		var sky: Color = p["sky"]
		var ground: Color = p["ground"]
		_check(name != "" and sky != ground, "%d '%s': sky and ground differ" % [i, name])
		for j in range(i):
			var q: Dictionary = Backdrop.PALETTES[j]
			_check(q["sky"] != sky and q["ground"] != ground,
				"%d '%s' shares neither colour with %d '%s'" % [i, name, j, q["name"]])
		_check(ground.get_luminance() >= empty_luma + 0.2,
			"%d '%s': ground (luma %.2f) is clearly lighter than an empty cell (%.2f)"
			% [i, name, ground.get_luminance(), empty_luma])
		var outline := Backdrop.outline_for(ground)
		_check(absf(outline.get_luminance() - Backdrop.OUTLINE_LUMINANCE) < 0.01 and absf(outline.a - Backdrop.OUTLINE_ALPHA) < 0.001,
			"%d '%s': HUD outline luma %.2f, alpha %.1f" % [i, name, outline.get_luminance(), outline.a])
		var scale: float = outline.r / ground.r
		_check(absf(outline.g / ground.g - scale) < 0.001 and absf(outline.b / ground.b - scale) < 0.001,
			"%d '%s': the outline keeps the ground's hue" % [i, name])

	print("Level.tscn is authored in the first palette")
	var authored: Node = load("res://scenes/Level.tscn").instantiate()
	var first: Dictionary = Backdrop.PALETTES[0]
	_check(authored.get_node("Background/Sky").color == first["sky"], "authored sky is the meadow sky")
	_check(authored.get_node("Background/Grass").color == first["ground"], "authored grass is the meadow ground")
	var meadow_outline := Backdrop.outline_for(first["ground"])
	for node in ["UI/HUD/LevelLabel", "UI/HUD/StatusLabel", "UI/HUD/BudgetLabel"]:
		var authored_outline: Color = authored.get_node(node).get_theme_color("font_outline_color")
		_check(_same_color(authored_outline, meadow_outline),
			"%s's authored outline is the meadow's derived one" % node.get_file())
	authored.free()

	print("A level paints its band")
	for spec in [
		["res://data/levels/tutorial_1.tres", 0],
		["res://data/levels/level_001.tres", 0],
		["res://data/levels/level_011.tres", 1],
		["res://data/levels/level_047.tres", 4],
		["res://data/levels/level_100.tres", 9],
	]:
		var level := await _open(spec[0])
		var palette: Dictionary = Backdrop.PALETTES[spec[1]]
		var label: String = spec[0].get_file().get_basename()
		_check(level.get_node("Background/Sky").color == palette["sky"],
			"%s sky is '%s'" % [label, palette["name"]])
		_check(level.get_node("Background/Grass").color == palette["ground"],
			"%s ground is '%s'" % [label, palette["name"]])
		var outline := Backdrop.outline_for(palette["ground"])
		var all_labels := true
		for node in ["UI/HUD/LevelLabel", "UI/HUD/StatusLabel", "UI/HUD/BudgetLabel"]:
			if not _same_color(level.get_node(node).get_theme_color("font_outline_color"), outline):
				all_labels = false
		_check(all_labels, "%s HUD outlines follow the ground" % label)
		level.free()

	if _failures == 0:
		print("BACKDROPS PASS")
	else:
		printerr("BACKDROPS FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
