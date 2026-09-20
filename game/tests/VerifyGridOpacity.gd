extends Node

## The Options menu's hex grid opacity slider. Settings.grid_opacity is
## clamped to 0..1 and persisted under [display] in user://settings.cfg;
## the slider shows it on open and writes it on every change; a board
## applies it to an EMPTY cell's fill and nothing else; and a board frozen
## under the pause menu's Options popup still repaints when it moves.
##
##   godot --headless res://tests/VerifyGridOpacity.tscn
##
## Uses save slot 99. Touches the real device settings file, and puts the
## grid opacity it found there back before quitting.

var _failures := 0
var _fired: Array[float] = []


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	GameState.current_slot = 99
	var original: float = Settings.grid_opacity
	Settings.grid_opacity_changed.connect(func(v: float): _fired.append(v))

	print("Settings")
	Settings.grid_opacity = 1.0
	_check(Settings.grid_opacity == 1.0, "full opacity is 1.0")
	Settings.grid_opacity = 0.4
	_check(is_equal_approx(Settings.grid_opacity, 0.4), "sets to 0.4")
	_check(_fired.size() == 2 and is_equal_approx(_fired.back(), 0.4),
		"grid_opacity_changed fired once per set, last with 0.4")
	Settings.grid_opacity = 1.7
	_check(Settings.grid_opacity == 1.0, "clamped to 1 from above")
	Settings.grid_opacity = -0.3
	_check(Settings.grid_opacity == 0.0, "clamped to 0 from below")
	_check(_fired.back() == 0.0, "the signal carries the clamped value")

	Settings.grid_opacity = 0.4
	var cfg := ConfigFile.new()
	_check(cfg.load(Settings.SETTINGS_PATH) == OK, "settings.cfg is written on set")
	_check(is_equal_approx(float(cfg.get_value(Settings.SECTION_DISPLAY, "grid_opacity", -1.0)), 0.4),
		"grid_opacity is persisted under [%s]" % Settings.SECTION_DISPLAY)
	_check(cfg.has_section_key(Settings.SECTION, "music_muted") and cfg.has_section_key(Settings.SECTION, "sfx_muted"),
		"the audio keys are still written alongside it")

	# A fresh launch: the in-memory value is 1.0, the file says 0.25.
	Settings.grid_opacity = 1.0
	cfg.set_value(Settings.SECTION_DISPLAY, "grid_opacity", 0.25)
	cfg.save(Settings.SETTINGS_PATH)
	Settings._load()
	_check(is_equal_approx(Settings.grid_opacity, 0.25), "_load() reads 0.25 back from the file")
	cfg.set_value(Settings.SECTION_DISPLAY, "grid_opacity", 3.0)
	cfg.save(Settings.SETTINGS_PATH)
	Settings._load()
	_check(Settings.grid_opacity == 1.0, "a file value out of range is clamped on load")
	cfg.erase_section(Settings.SECTION_DISPLAY)
	cfg.save(Settings.SETTINGS_PATH)
	Settings._load()
	_check(Settings.grid_opacity == 1.0, "a file from before the slider existed means fully opaque")

	print("Board")
	GameState.pending_level_path = "res://data/levels/level_001.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _frames(6)
	var board: HexBoard = level.board
	var table: Color = HexBoard.TILE_VISUALS[HexBoard.TILE_EMPTY]["fill"]
	Settings.grid_opacity = 0.4
	var fill: Color = board.empty_fill()
	_check(is_equal_approx(fill.a, 0.4), "an empty cell's fill has alpha 0.4 at 40%")
	_check(fill.r == table.r and fill.g == table.g and fill.b == table.b,
		"only its alpha changes; the colour is the table's")
	Settings.grid_opacity = 0.0
	_check(board.empty_fill().a == 0.0, "0% is fully transparent")
	Settings.grid_opacity = 1.0
	_check(board.empty_fill() == table, "100% is exactly the table colour")
	_check(HexBoard.TILE_VISUALS[HexBoard.TILE_FIRE]["fill"].a == 1.0
		and HexBoard.TILE_VISUALS[HexBoard.TILE_POOL]["fill"].a == 1.0,
		"terrain fills are not routed through the slider")

	print("Options menu")
	Settings.grid_opacity = 0.4
	level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	await _frames(2)
	level._on_pause_pressed()
	await _frames(2)
	var menu: OptionsMenu = level.options_menu
	var fired_before_open := _fired.size()
	menu.open()
	await _frames(2)
	_check(menu.visible, "open() shows the popup over the pause menu")
	_check(menu.grid_opacity_slider.value == 40.0, "the slider shows 40 on open")
	_check(menu.grid_opacity_value.text == "40%", "and the label reads 40%")
	_check(_fired.size() == fired_before_open, "opening the menu does not write the setting back")
	_check(menu.grid_opacity_slider.min_value == 0.0 and menu.grid_opacity_slider.max_value == 100.0
		and menu.grid_opacity_slider.step == 5.0, "the slider runs 0-100 in steps of 5")
	menu.grid_opacity_slider.value = 65.0
	await _frames(1)
	_check(is_equal_approx(Settings.grid_opacity, 0.65), "moving the slider writes Settings.grid_opacity")
	_check(menu.grid_opacity_value.text == "65%", "and the label follows it")
	_check(is_equal_approx(board.empty_fill().a, 0.65), "and the board's empty fill follows it")

	print("Live repaint under the popup")
	_check(not board.is_processing(), "the board's heartbeat is off under the Options popup")
	var draws := [0]
	board.draw.connect(func(): draws[0] += 1)
	await _frames(5)
	_check(draws[0] == 0, "an idle covered board does not repaint")
	menu.grid_opacity_slider.value = 30.0
	await _frames(2)
	_check(draws[0] == 1, "moving the slider repaints it exactly once")

	Settings.grid_opacity = original
	level.free()

	if _failures == 0:
		print("GRID OPACITY PASS")
	else:
		printerr("GRID OPACITY FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
