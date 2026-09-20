extends Node

## The sound effect system. Three things must agree -- Sfx.SOUNDS, the
## .wav files under assets/sfx/, and the recipes in tools/gen_sfx.py --
## and every play() in the game must name a sound that exists. Then the
## player itself: voices on the SFX bus, the repeat throttle, play_after,
## an unknown name warning once instead of crashing, the bus mute. Then
## the wiring: buttons tap, Start/Pause/Resume have their own sounds, board
## taps place/pick up/refuse, a ready Hydro Plant's double-tap does not
## buzz, a level played to its win sounds the water, the fire, the lake
## and the jingle in the right order, and the same level retried and lost
## off the edge sounds the splash and then the sting.
##
##   godot --headless res://tests/VerifySfx.tscn
##
## Then the Options menu's effects volume slider: the SFX bus gain,
## persistence, and the slider mirroring the setting.
##
## Uses save slot 99. Restores Settings.sfx_muted and sfx_volume to what
## it found.

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


## Long enough for Sfx.REPEAT_WINDOW_MSEC to pass.
func _past_throttle() -> void:
	await get_tree().create_timer(Sfx.REPEAT_WINDOW_MSEC / 1000.0 + 0.02).timeout


## Every .wav under the sound directory, by name.
func _wav_names() -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(Sfx.SFX_DIR):
		if file.ends_with(".wav"):
			names.append(file.trim_suffix(".wav"))
	names.sort()
	return names


## The names in tools/gen_sfx.py's SOUNDS table.
func _recipe_names() -> Array[String]:
	var names: Array[String] = []
	var source := FileAccess.get_file_as_string("res://tools/gen_sfx.py")
	var table_start := source.find("SOUNDS = {")
	var table_end := source.find("}", table_start)
	var entry := RegEx.create_from_string("\"([^\"]+)\":\\s*\\w+")
	for m in entry.search_all(source.substr(table_start, table_end - table_start)):
		names.append(m.get_string(1))
	names.sort()
	return names


## The one place a sound name reaches play() other than as a literal:
## Level's board-event table, whose values are read off the script below.
## Any other non-literal argument is a call this scan cannot see, and is
## reported as a failure rather than silently skipped.
const KNOWN_LOOKUPS: Array[String] = ["BOARD_SOUNDS[kind]"]

## Every sound name the game's scripts ask for, with where. Scans every
## Sfx.play / play_after / play.bind call under res://scripts for its first
## argument -- a literal in either quote style, with or without the & --
## and checks the rest against KNOWN_LOOKUPS. tests/ and tools/ are not
## scanned: this test's own bad name must not count, and the tools never
## play a sound.
func _played_names() -> Dictionary:
	var found := {}
	var call := RegEx.create_from_string("Sfx\\.play(?:_after)?(?:\\.bind)?\\(\\s*([^,)]+)")
	var literal := RegEx.create_from_string("^&?[\"']([^\"']+)[\"']$")
	for path in _gd_files("res://scripts"):
		var code: PackedStringArray = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.strip_edges().begins_with("#"): # a play() in a comment is not a call
				code.append(line)
		for m in call.search_all("\n".join(code)):
			var arg := m.get_string(1).strip_edges()
			var lit := literal.search(arg)
			if lit != null:
				found[lit.get_string(1)] = path
			else:
				_check(KNOWN_LOOKUPS.has(arg),
					"%s passes Sfx.play a non-literal this scan knows (%s)" % [path, arg])
	# Level.gd has no class_name; its constants are read off the script.
	var board_sounds: Dictionary = load("res://scripts/gameplay/Level.gd").BOARD_SOUNDS
	for kind in board_sounds:
		found[String(board_sounds[kind])] = "Level.BOARD_SOUNDS"
	return found


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(sub)))
	return out


func _ready() -> void:
	GameState.current_slot = 99
	var muted_before: bool = Settings.sfx_muted
	var volume_before: float = Settings.sfx_volume
	Settings.sfx_muted = false
	Settings.sfx_volume = 1.0

	print("The catalogue, the files and the recipes agree")
	var catalogue: Array[String] = []
	for sound in Sfx.SOUNDS:
		catalogue.append(String(sound))
	catalogue.sort()
	_check(catalogue.size() >= 10, "%d sounds in Sfx.SOUNDS" % catalogue.size())
	_check(_wav_names() == catalogue,
		"every catalogue entry has a .wav and every .wav a catalogue entry (files: %s)" % ", ".join(_wav_names()))
	_check(_recipe_names() == catalogue,
		"tools/gen_sfx.py has exactly the same names (%s)" % ", ".join(_recipe_names()))
	var snake := RegEx.create_from_string("^[a-z0-9_]+$")
	for sound in Sfx.SOUNDS:
		var entry: Dictionary = Sfx.SOUNDS[sound]
		_check(snake.search(String(sound)) != null,
			"%s is lowercase letters, digits and underscores -- it is the .wav name and the recipe key" % sound)
		_check(entry.has("when") and entry["when"] != "" and entry.has("vary") and entry["vary"] >= 0.0 and entry["vary"] < 0.5,
			"%s says when it plays and has a sane pitch spread" % sound)
		var stream: AudioStream = load(Sfx.SFX_DIR + String(sound) + ".wav")
		_check(stream != null and stream.get_length() > 0.02 and stream.get_length() < 3.0,
			"%s loads as a short one-shot (%.2fs)" % [sound, stream.get_length() if stream else 0.0])
		if stream is AudioStreamWAV:
			_check((stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s does not loop" % sound)

	print("Every play() in the game names a sound that exists")
	var played := _played_names()
	_check(played.size() >= 10, "%d distinct sounds are asked for by scripts/" % played.size())
	for name in played:
		_check(Sfx.SOUNDS.has(StringName(name)), "%s (from %s) is in the catalogue" % [name, played[name]])
	var unused: Array[String] = []
	for name in catalogue:
		if not played.has(name) and name != String(Sfx.TAP_SOUND):
			unused.append(name)
	_check(unused.is_empty(), "every catalogue sound is used somewhere (unused: %s)" % ", ".join(unused))
	_check(Sfx.SOUNDS.has(Sfx.TAP_SOUND), "the button tap (%s) is in the catalogue" % Sfx.TAP_SOUND)

	print("The player")
	_check(Sfx.get_child_count() == Sfx.VOICES, "%d voices" % Sfx.VOICES)
	var on_bus := true
	for child in Sfx.get_children():
		if not (child is AudioStreamPlayer) or (child as AudioStreamPlayer).bus != StringName(Sfx.BUS):
			on_bus = false
	_check(on_bus, "every voice is an AudioStreamPlayer on the '%s' bus" % Sfx.BUS)
	_check(AudioServer.get_bus_index(Sfx.BUS) != -1, "the '%s' bus exists in the layout" % Sfx.BUS)
	var heard: Array[StringName] = []
	Sfx.played.connect(func(s: StringName): heard.append(s))
	await _past_throttle()
	_check(Sfx.play(&"place"), "play() starts a sound")
	_check(Sfx.history.back() == &"place" and heard == [&"place"], "and records it in history and the played signal")
	_check(Sfx.is_playing(&"place"), "is_playing() sees it on a voice")
	_check(not Sfx.play(&"place"), "the same sound again inside the repeat window is throttled")
	_check(Sfx.play(&"pickup"), "a different sound is not")
	await _past_throttle()
	_check(Sfx.play(&"place"), "and the same sound plays again once the window has passed")
	var warned_before: int = Sfx._warned.size()
	_check(not Sfx.play(&"no_such_sound"), "an unknown name returns false rather than crashing")
	_check(not Sfx.play(&"no_such_sound") and Sfx._warned.size() == warned_before + 1 and Sfx._warned.has(&"no_such_sound"),
		"and again, silently -- it warned exactly once")
	var before_after := heard.size()
	Sfx.play_after(&"win", 0.1)
	await get_tree().create_timer(0.05).timeout
	_check(heard.size() == before_after, "play_after() has not fired at half its delay")
	await get_tree().create_timer(0.15).timeout
	_check(heard.size() == before_after + 1 and heard.back() == &"win", "and has once the delay passed")
	Settings.sfx_muted = true
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.BUS)), "Settings.sfx_muted mutes the bus")
	await _past_throttle()
	_check(Sfx.play(&"pickup"), "a muted sound still 'plays' -- the bus is what silences it")
	Settings.sfx_muted = false
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.BUS)), "and unmuting restores the bus")

	print("Wiring: the level's buttons and taps")
	GameState.pending_level_path = "res://data/levels/level_001.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _frames(4)
	var board: HexBoard = level.board
	heard.clear()
	await _past_throttle()
	level.intro_got_it_button.pressed.emit()
	_check(heard == [Sfx.TAP_SOUND], "a HUD button taps")
	heard.clear()
	await _past_throttle()
	var tile: Button = level.inventory_bar.get_node("block_wall")
	tile.pressed.emit()
	_check(heard == [Sfx.TAP_SOUND], "an inventory tile taps")
	heard.clear()
	var cell := Vector2i(-1, -3)
	var screen_pos: Vector2 = board.to_global(Hex.axial_to_pixel(cell))
	level._handle_tap(screen_pos)
	_check(board.placed_blocks.has(cell) and heard == [&"place"], "placing a block sounds 'place'")
	heard.clear()
	await _past_throttle()
	level._handle_tap(screen_pos)
	_check(not board.placed_blocks.has(cell) and heard == [&"pickup"], "tapping it again picks it up with 'pickup'")
	heard.clear()
	await _past_throttle()
	level._handle_tap(screen_pos)
	heard.clear()
	await _past_throttle()
	var source_pos: Vector2 = board.to_global(Hex.axial_to_pixel(level.level_data.water_sources[0]))
	level._handle_tap(source_pos)
	_check(heard == [&"invalid"], "a placement the board refuses sounds 'invalid' (got %s)" % [heard])
	heard.clear()
	await _past_throttle()
	level.start_button.pressed.emit()
	_check(heard == [&"start"], "Start sounds 'start' and not the generic tap (got %s)" % [heard])
	heard.clear()
	await _past_throttle()
	level.pause_button.pressed.emit()
	_check(heard == [&"pause"], "Pause sounds 'pause' only (got %s)" % [heard])
	heard.clear()
	await _past_throttle()
	level.pause_resume_button.pressed.emit()
	_check(heard == [&"resume"], "Resume sounds 'resume' only (got %s)" % [heard])
	level.tick_timer.stop() # drive the beats by hand below

	print("Wiring: a level played through")
	heard.clear()
	var measures := 0
	while measures < 30 and not board.game_over:
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		measures += 1
		await _past_throttle()
	_check(board.game_over and not board.lose_reason, "level 1 is won by the documented wall in %d measures" % measures)
	var heard_at_win := heard.size()
	await get_tree().create_timer(level.WIN_AFTER_LAST_CHIME_SEC + 0.1).timeout
	_check(heard.has(&"drop"), "the water sounded as it moved")
	_check(heard.has(&"fire_out"), "the fire going out sounded")
	_check(heard.count(&"pool_fill") == 3 and heard.count(&"pool_full") == 1,
		"the lake sounded three fills and then one full (got %s)" % [heard])
	_check(heard[heard_at_win - 1] == &"pool_full", "the lake filling was the last thing heard on the winning beat")
	_check(heard.size() == heard_at_win + 1 and heard.back() == &"win",
		"and the win jingle followed it %.1fs later, alone" % level.WIN_AFTER_LAST_CHIME_SEC)
	_check(heard.find(&"fire_out") < heard.find(&"pool_full") and heard.find(&"pool_fill") < heard.find(&"pool_full"),
		"fire and filling came before full")
	heard.clear()
	await _past_throttle()
	level._handle_tap(screen_pos)
	_check(heard.is_empty(), "a press released under the win panel makes no sound")

	print("Wiring: the same level retried and lost off the edge")
	await _past_throttle()
	level.pause_retry_button.pressed.emit()
	_check(heard == [Sfx.TAP_SOUND] and not board.game_over, "Retry taps and resets the board")
	heard.clear()
	await _past_throttle()
	(level.inventory_bar.get_node("block_wall") as Button).pressed.emit()
	_check(heard == [Sfx.TAP_SOUND], "the rebuilt inventory bar is hooked exactly once")
	heard.clear()
	await _past_throttle()
	level.start_button.pressed.emit()
	level.tick_timer.stop()
	_check(heard == [&"start"], "Start sounds again after a Retry")
	heard.clear()
	measures = 0
	while measures < 30 and not board.game_over:
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		measures += 1
		await _past_throttle()
	_check(board.game_over and board.lose_reason == HexBoard.LoseReason.EDGE,
		"with no wall, level 1 runs off the bottom edge in %d measures" % measures)
	var splash_at := heard.find(&"splash")
	_check(splash_at != -1 and heard.back() == &"splash", "the splash is the last thing heard on the losing beat (got %s)" % [heard])
	_check(heard.slice(0, maxi(splash_at, 0)).has(&"drop") and not heard.slice(splash_at + 1).has(&"drop"),
		"the water sounded before the loss and not after it")
	var heard_at_loss := heard.size()
	await get_tree().create_timer(level.LOSE_AFTER_SPLASH_SEC + 0.1).timeout
	_check(heard.size() == heard_at_loss + 1 and heard.back() == &"lose",
		"and the sting followed it %.2fs later, alone" % level.LOSE_AFTER_SPLASH_SEC)
	level.free()

	print("Wiring: a ready Hydro Plant's double-tap")
	GameState.pending_level_path = "res://data/levels/level_007.tres"
	level = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _frames(4)
	board = level.board
	level.intro_got_it_button.pressed.emit()
	(level.inventory_bar.get_node("block_splitter") as Button).pressed.emit()
	var plant := Vector2i(0, 2)
	_check(board.place_block(Vector2i(0, -2), "splitter"), "level 7's documented Splitter goes down")
	level.start_button.pressed.emit()
	level.tick_timer.stop()
	measures = 0
	while measures < 30 and not board.game_over and not board.hydro_ready_at(plant):
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		measures += 1
	_check(board.hydro_ready_at(plant) and not board.game_over, "water reaches the plant in %d measures" % measures)
	_check(board.selected_block_id != "", "a block is still selected, as it is for most of a run")
	heard.clear()
	await _past_throttle()
	var plant_pos: Vector2 = board.to_global(Hex.axial_to_pixel(plant))
	level._handle_tap(plant_pos)
	_check(heard.is_empty(), "the first tap of the double-tap does not buzz 'invalid' (got %s)" % [heard])
	level._handle_tap(plant_pos)
	_check(heard == [&"hydro"] and board.all_hydro_plants_running(), "the second switches the plant on with 'hydro'")
	heard.clear()
	await _past_throttle()
	level._handle_tap(plant_pos)
	_check(heard == [&"invalid"], "a tap on the running plant -- a water source now -- buzzes like any source")
	level.free()

	print("The volume dial")
	var bus := AudioServer.get_bus_index(Sfx.BUS)
	_check(absf(AudioServer.get_bus_volume_db(bus)) < 0.01, "at volume 1.0 the SFX bus sits at 0 dB")
	Settings.sfx_volume = 0.5
	_check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) < 0.01,
		"0.5 is -6 dB on the bus (%.2f)" % AudioServer.get_bus_volume_db(bus))
	Settings.sfx_volume = 0.0
	_check(absf(AudioServer.get_bus_volume_db(bus) - Settings.SILENT_VOLUME_DB) < 0.01, "0 is the silent floor, not -inf")
	Settings.sfx_volume = 1.4
	_check(Settings.sfx_volume == 1.0, "clamped from above")
	Settings.sfx_volume = 0.4
	Settings.sfx_muted = true
	_check(AudioServer.is_bus_mute(bus) and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.4)) < 0.01,
		"the mute is separate: muting keeps the dial where it was")
	Settings.sfx_muted = false
	var music_bus := AudioServer.get_bus_index(Settings.BUS_MUSIC)
	_check(absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(Settings.music_volume)) < 0.01,
		"the effects dial leaves the music bus at the music dial")
	var cfg := ConfigFile.new()
	_check(cfg.load(Settings.SETTINGS_PATH) == OK and is_equal_approx(float(cfg.get_value(Settings.SECTION, "sfx_volume", -1.0)), 0.4),
		"sfx_volume is persisted under [%s]" % Settings.SECTION)
	Settings.sfx_volume = 1.0
	cfg.set_value(Settings.SECTION, "sfx_volume", 0.25)
	cfg.save(Settings.SETTINGS_PATH)
	Settings._load()
	_check(is_equal_approx(Settings.sfx_volume, 0.25) and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.01,
		"_load() reads it back and applies it to the bus")
	cfg.erase_section_key(Settings.SECTION, "sfx_volume")
	cfg.save(Settings.SETTINGS_PATH)
	Settings._load()
	_check(Settings.sfx_volume == 1.0, "a file from before the dial means full volume")

	print("The Options menu's slider")
	Settings.sfx_volume = 0.4
	var options: OptionsMenu = load("res://scenes/OptionsMenu.tscn").instantiate()
	add_child(options)
	await _frames(2)
	options.open()
	_check(options.sfx_volume_slider.value == 40.0 and options.sfx_volume_value.text == "40%", "open() shows the dial at 40%")
	_check(options.sfx_volume_slider.min_value == 0.0 and options.sfx_volume_slider.max_value == 100.0
		and options.sfx_volume_slider.step == 5.0, "the slider runs 0-100 in steps of 5")
	await _past_throttle()
	heard.clear()
	options.sfx_volume_slider.value = 70.0
	_check(is_equal_approx(Settings.sfx_volume, 0.7) and options.sfx_volume_value.text == "70%"
		and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.7)) < 0.01,
		"moving it writes Settings, the label and the bus at once")
	_check(heard.is_empty(), "and dragging a slider is not a button tap")
	options.free()

	Settings.sfx_volume = volume_before
	Settings.sfx_muted = muted_before
	if _failures == 0:
		print("SFX PASS")
	else:
		printerr("SFX FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
