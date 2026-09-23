extends Node

## The moving backdrop (AmbientBackdrop): clouds and their shadows, birds,
## stars. Checks that every band's ambience keeps the screen readable --
## clouds that show on their sky, shadows that leave the ground as clear of
## an empty cell as the ground itself, birds and stars that read -- that a
## level and the main menu both carry it, in the right band, taking no
## taps; that everything stays in its half of the screen; that it moves,
## and stops with the board and with the Options toggle, and picks up where
## it stopped rather than jumping.
##
##   godot --headless res://tests/VerifyAmbience.tscn
##
## Uses save slot 99. Touches the real device settings file, and puts the
## motion setting it found there back before quitting.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _open(path: String) -> Node:
	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _frames(4)
	return level


func _close(node: Node) -> void:
	node.queue_free()
	remove_child(node)
	await _frames(1)


func _clouds(amb: AmbientBackdrop) -> Array:
	return amb.get_children().filter(func(c): return c is AmbientBackdrop.Cloud)


func _shadows(amb: AmbientBackdrop) -> Array:
	return amb.get_children().filter(func(c): return c is Sprite2D)


func _birds(amb: AmbientBackdrop) -> Array:
	return amb.get_children().filter(func(c): return c is AmbientBackdrop.Bird)


func _stars(amb: AmbientBackdrop) -> Array:
	return amb.get_children().filter(func(c): return c is AmbientBackdrop.Stars)


func _ready() -> void:
	GameState.current_slot = 99
	var original_motion: bool = Settings.background_motion
	Settings.background_motion = true

	print("Every band's ambience keeps the screen readable")
	var empty_luma: float = HexBoard.TILE_VISUALS[HexBoard.TILE_EMPTY]["fill"].get_luminance()
	for i in range(Backdrop.PALETTES.size()):
		var p: Dictionary = Backdrop.PALETTES[i]
		var name: String = p["name"]
		var sky: Color = p["sky"]
		var ground: Color = p["ground"]
		var fields_ok: bool = p.get("cloud") is Color and p.get("clouds") is int \
			and p.get("shadow") is float and p.get("birds") is bool and p.get("stars") is bool
		_check(fields_ok, "%d '%s': has cloud, clouds, shadow, birds and stars" % [i, name])
		if not fields_ok:
			continue
		_check(p["clouds"] >= 0 and p["clouds"] <= 8, "%d '%s': %d clouds" % [i, name, p["clouds"]])
		var near := sky.lerp(p["cloud"], AmbientBackdrop.NEAR_STRENGTH)
		var far := sky.lerp(p["cloud"], AmbientBackdrop.FAR_STRENGTH)
		_check(absf(near.get_luminance() - sky.get_luminance()) >= 0.08,
			"%d '%s': a near cloud stands out from the sky (luma %.2f on %.2f)"
			% [i, name, near.get_luminance(), sky.get_luminance()])
		_check(absf(far.get_luminance() - sky.get_luminance()) >= 0.04,
			"%d '%s': so does a far one, more faintly (luma %.2f)" % [i, name, far.get_luminance()])
		var outline := Backdrop.outline_for(ground)
		var shadowed := ground.lerp(Color(outline, 1.0), p["shadow"])
		_check(p["shadow"] >= 0.0 and p["shadow"] <= 0.2 and shadowed.get_luminance() >= empty_luma + 0.2,
			"%d '%s': ground under a shadow (luma %.2f) is still clearly lighter than an empty cell"
			% [i, name, shadowed.get_luminance()])
		if p["birds"]:
			var bird := sky.lerp(Color(outline, 1.0), AmbientBackdrop.BIRD_ALPHA)
			_check(sky.get_luminance() - bird.get_luminance() >= 0.25,
				"%d '%s': birds read on the sky (luma %.2f on %.2f)"
				% [i, name, bird.get_luminance(), sky.get_luminance()])
		if p["stars"]:
			_check(AmbientBackdrop.STAR_COLOR.get_luminance() - sky.get_luminance() >= 0.3,
				"%d '%s': the sky is dark enough for stars (luma %.2f)" % [i, name, sky.get_luminance()])

	print("Held to the scenes it sits in")
	_check(AmbientBackdrop.TICK_FPS == HexBoard.ANIM_TICK_FPS, "ticks at the board's heartbeat rate")
	for scene_path in ["res://scenes/Level.tscn", "res://scenes/MainMenu.tscn"]:
		var scene: Node = load(scene_path).instantiate()
		var root: String = "Background/" if scene_path.ends_with("Level.tscn") else ""
		var sky_rect: Control = scene.get_node(root + "Sky")
		var grass_rect: Control = scene.get_node(root + "Grass")
		var amb: Node = scene.get_node_or_null(root + "Ambient")
		var file: String = scene_path.get_file()
		_check(is_equal_approx(sky_rect.anchor_bottom, AmbientBackdrop.HORIZON)
			and is_equal_approx(grass_rect.anchor_top, AmbientBackdrop.HORIZON),
			"%s: the sky/ground split is AmbientBackdrop.HORIZON" % file)
		_check(amb is AmbientBackdrop, "%s has an Ambient layer" % file)
		if amb is AmbientBackdrop:
			_check(amb.get_index() == grass_rect.get_index() + 1, "%s: it sits just over the ground" % file)
			_check(amb.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: it takes no taps" % file)
		scene.free()

	print("A level carries its band")
	for spec in [
		["res://data/levels/tutorial_1.tres", 0],
		["res://data/levels/level_001.tres", 0],
		["res://data/levels/level_015.tres", 1],
		["res://data/levels/level_035.tres", 3],
		["res://data/levels/level_075.tres", 7],
		["res://data/levels/level_095.tres", 9],
	]:
		var level := await _open(spec[0])
		var amb: AmbientBackdrop = level.get_node("Background/Ambient")
		var p: Dictionary = Backdrop.PALETTES[spec[1]]
		var label: String = spec[0].get_file().get_basename()
		_check(amb.band == spec[1], "%s: band %d, '%s'" % [label, spec[1], p["name"]])
		_check(_clouds(amb).size() == p["clouds"], "%s: %d clouds" % [label, p["clouds"]])
		var near: int = p["clouds"] - p["clouds"] / 2
		_check(_shadows(amb).size() == (near if p["shadow"] > 0.0 else 0),
			"%s: a shadow under each near cloud%s" % [label, "" if p["shadow"] > 0.0 else " -- none, no sun"])
		_check((_birds(amb).size() > 0) == p["birds"], "%s: birds %s" % [label, "cross" if p["birds"] else "do not"])
		_check((_stars(amb).size() > 0) == p["stars"], "%s: stars %s" % [label, "shine" if p["stars"] else "do not"])

		var horizon := amb.sky_height()
		var in_sky := true
		for c: AmbientBackdrop.Cloud in _clouds(amb):
			if c.position.y - c.height() - AmbientBackdrop.UNDERSIDE_DROP < 0.0 or c.position.y > horizon:
				in_sky = false
		_check(in_sky, "%s: every cloud is wholly in the sky" % label)
		var on_ground := true
		for s: Sprite2D in _shadows(amb):
			var half_h: float = s.scale.y * AmbientBackdrop.SHADOW_TEXTURE_SIZE * 0.5
			if s.position.y - half_h < horizon - 0.5 or s.position.y + half_h > amb.size.y + 0.5:
				on_ground = false
		_check(on_ground, "%s: every shadow is wholly on the ground" % label)
		for st: AmbientBackdrop.Stars in _stars(amb):
			_check(st.points.all(func(v: Vector3): return v.y > 0.0 and v.y < horizon),
				"%s: every star is in the sky" % label)
		await _close(level)

	print("The same band lays out the same way every visit")
	var a := await _open("res://data/levels/level_001.tres")
	var b := await _open("res://data/levels/level_001.tres")
	# Both at the same moment of the drift, so only the layout is compared.
	for opened in [a, b]:
		opened.get_node("Background/Ambient")._time = 0.0
		opened.get_node("Background/Ambient")._place()
	var pos_a := _clouds(a.get_node("Background/Ambient")).map(func(c): return c.position)
	var pos_b := _clouds(b.get_node("Background/Ambient")).map(func(c): return c.position)
	_check(pos_a.size() > 0 and pos_a == pos_b, "two opens of level 1 put the clouds in the same places")
	await _close(a)
	await _close(b)

	print("Moving, and stopping with the board")
	var level := await _open("res://data/levels/level_001.tres")
	var amb: AmbientBackdrop = level.get_node("Background/Ambient")
	var board: HexBoard = level.get_node("Board")
	var intro: Control = level.get_node("UI/IntroPanel")
	_check(intro.visible and not amb.is_processing(), "still behind the intro popup, like the board")
	level.get_node("UI/IntroPanel/Center/Panel/VBox/GotItButton").pressed.emit()
	await _frames(3)
	_check(amb.is_processing() and board.is_processing(), "moving once the popup is gone")
	var cloud: Node2D = _clouds(amb)[0]
	var x_before := cloud.position.x
	var t_before := amb._time
	await _frames(30)
	_check(amb._time > t_before and cloud.position.x != x_before, "the clock advances and the clouds drift")

	level._on_pause_pressed()
	await _frames(3)
	_check(not amb.is_processing(), "stops when paused")
	var t_paused := amb._time
	var x_paused := cloud.position.x
	await _frames(30)
	_check(amb._time == t_paused and cloud.position.x == x_paused, "and stays exactly where it stopped")
	level._on_resume_pressed()
	await _frames(3)
	_check(amb.is_processing(), "moves again on Resume")
	_check(amb._time > t_paused and amb._time - t_paused < 1.0,
		"carrying on from where it stopped (%.2fs on), not jumping" % (amb._time - t_paused))

	level.notification(NOTIFICATION_APPLICATION_PAUSED)
	await _frames(3)
	_check(not amb.is_processing(), "stops when the app loses the foreground")
	level._on_resume_pressed()
	await _frames(3)
	_check(amb.is_processing(), "and starts again on the way back in")

	print("The Options toggle")
	Settings.background_motion = false
	await _frames(2)
	_check(not amb.is_processing(), "switched off, it stops at once")
	var t_off := amb._time
	await _frames(20)
	_check(amb._time == t_off and _clouds(amb).size() > 0, "frozen, with the scenery still there")
	Settings.background_motion = true
	await _frames(2)
	_check(amb.is_processing(), "switched on, it moves again")

	level.options_menu.open()
	var toggle: CheckButton = level.options_menu.motion_toggle
	_check(toggle.button_pressed, "the toggle shows it on")
	toggle.button_pressed = false
	_check(not Settings.background_motion, "turning the toggle off writes the setting")
	level.options_menu.close()
	Settings.background_motion = false
	level.options_menu.open()
	_check(not toggle.button_pressed, "and opening Options shows it off")
	level.options_menu.close()
	Settings.background_motion = true

	var cfg := ConfigFile.new()
	Settings.background_motion = false
	_check(cfg.load(Settings.SETTINGS_PATH) == OK
		and cfg.get_value(Settings.SECTION_DISPLAY, "background_motion", true) == false,
		"persisted under [%s]" % Settings.SECTION_DISPLAY)
	cfg.set_value(Settings.SECTION_DISPLAY, "background_motion", true)
	cfg.save(Settings.SETTINGS_PATH)
	Settings._load()
	_check(Settings.background_motion, "_load() reads it back")
	# Off in memory, and no key in the file: loading must turn it on.
	Settings.background_motion = false
	cfg.load(Settings.SETTINGS_PATH)
	cfg.erase_section_key(Settings.SECTION_DISPLAY, "background_motion")
	cfg.save(Settings.SETTINGS_PATH)
	Settings._load()
	_check(Settings.background_motion, "a file from before the toggle existed means moving")

	print("Drift wraps, and the flock comes and goes")
	var span_ok := true
	for t in [0.0, 37.0, 500.0, 12345.6]:
		amb._time = t
		amb._place()
		for c: Node2D in _clouds(amb):
			if c.position.x < -AmbientBackdrop.MARGIN - 0.01 or c.position.x > amb.size.x + AmbientBackdrop.MARGIN + 0.01:
				span_ok = false
	_check(span_ok, "every cloud stays inside its wrap loop however long it runs")
	amb._time = 0.0
	amb._place()
	_check(_birds(amb).all(func(bd): return not bd.visible), "no birds at the start")
	amb._time = AmbientBackdrop.FLOCK_FIRST + 8.0
	amb._place()
	_check(_birds(amb).any(func(bd): return bd.visible), "a flock a few seconds in")
	amb._time = AmbientBackdrop.FLOCK_FIRST + AmbientBackdrop.FLOCK_PERIOD - 1.0
	amb._place()
	_check(_birds(amb).all(func(bd): return not bd.visible), "and gone again before the next")
	await _close(level)

	print("The main menu")
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	add_child(menu)
	await _frames(4)
	var menu_amb: AmbientBackdrop = menu.get_node("Ambient")
	_check(menu_amb.band == 0 and _clouds(menu_amb).size() == Backdrop.PALETTES[0]["clouds"], "the meadow's clouds")
	t_before = menu_amb._time
	await _frames(10)
	_check(menu_amb.is_processing() and menu_amb._time > t_before, "drifting")
	await _close(menu)

	Settings.background_motion = original_motion

	if _failures == 0:
		print("AMBIENCE PASS")
	else:
		printerr("AMBIENCE FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
