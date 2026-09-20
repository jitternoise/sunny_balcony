extends Node

## Background music: one loop per ten levels, in step with the backdrops.
## The catalogue (Music.TRACKS), the files under assets/music/, the SONGS
## in tools/gen_music.py and Backdrop.PALETTES must all line up; every
## loop is a forward-looping 19.2 s WAV; the level-to-track mapping is
## the backdrop's; two voices on the Music bus crossfade, the same track
## asked for again is never restarted, stop() fades out, the bus mute
## works; and the main menu, a level and the map each start the right
## track -- the map the band of the level it opens on.
##
##   godot --headless res://tests/VerifyMusic.tscn
##
## Uses save slot 99. Restores Settings.music_muted to what it found.

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


func _after_fade() -> void:
	await get_tree().create_timer(Music.CROSSFADE_SEC + 0.3).timeout


func _wav_names() -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(Music.MUSIC_DIR):
		if file.ends_with(".wav"):
			names.append(file.trim_suffix(".wav"))
	names.sort()
	return names


func _song_names() -> Array[String]:
	var names: Array[String] = []
	var entry := RegEx.create_from_string("dict\\(name=\"([^\"]+)\"")
	for m in entry.search_all(FileAccess.get_file_as_string("res://tools/gen_music.py")):
		names.append(m.get_string(1))
	names.sort()
	return names


## "Spring meadow" -> "spring_meadow", the way the files are named.
func _slug(palette_name: String) -> String:
	return palette_name.to_lower().replace(" ", "_")


func _ready() -> void:
	GameState.current_slot = 99
	var muted_before: bool = Settings.music_muted
	Settings.music_muted = false

	print("The catalogue, the files, the songs and the palettes agree")
	var files: Array[String] = []
	for track in Music.TRACKS:
		files.append(String(track["file"]))
	files.sort()
	_check(Music.TRACKS.size() == Backdrop.PALETTES.size(),
		"one track per palette (%d)" % Music.TRACKS.size())
	_check(_wav_names() == files, "every track has a .wav and every .wav a track (files: %s)" % ", ".join(_wav_names()))
	_check(_song_names() == files, "tools/gen_music.py has exactly the same songs (%s)" % ", ".join(_song_names()))
	for i in range(Music.TRACKS.size()):
		var track: Dictionary = Music.TRACKS[i]
		var expected := "%02d_%s" % [i + 1, _slug(Backdrop.PALETTES[i]["name"])]
		_check(track["file"] == expected, "track %d is named for its palette (%s)" % [i, expected])
		_check(track.has("title") and track["title"] != "", "track %d has a title" % i)
		# A fresh instance, not the cached one: Music._ready() has already
		# patched the cached stream to loop, so a plain load() would only
		# ever see LOOP_FORWARD and this could not catch a bad import.
		var path := Music.MUSIC_DIR + String(track["file"]) + ".wav"
		var stream: AudioStream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_check(stream is AudioStreamWAV, "%s loads as a WAV stream" % track["file"])
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			_check(absf(wav.get_length() - 19.2) < 0.05, "%s is one 8-bar loop at 100 BPM (%.2fs)" % [track["file"], wav.get_length()])
			_check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops forward as imported" % track["file"])
			_check(wav.mix_rate == 22050, "%s is 22.05 kHz" % track["file"])
		_check(FileAccess.get_file_as_string(path + ".import").contains("edit/loop_mode=2"),
			"%s.import says edit/loop_mode=2 (Forward -- 1 is Disabled)" % track["file"])

	print("Which track a level gets")
	for pair in [[1, 0], [10, 0], [11, 1], [47, 4], [100, 9], [GameState.TUTORIAL_ID_FIRST, 0], [0, 0]]:
		_check(Music.track_for_level(pair[0]) == pair[1], "level %d plays track %d" % [pair[0], pair[1]])

	print("The player")
	_check(Music.get_child_count() == 2, "two voices")
	var on_bus := true
	for child in Music.get_children():
		if not (child is AudioStreamPlayer) or (child as AudioStreamPlayer).bus != StringName(Music.BUS):
			on_bus = false
	_check(on_bus, "both on the '%s' bus" % Music.BUS)
	_check(AudioServer.get_bus_index(Music.BUS) != -1, "the '%s' bus exists" % Music.BUS)
	var changes: Array[int] = []
	Music.track_changed.connect(func(i: int): changes.append(i))
	Music.stop()
	await _after_fade()
	changes.clear()
	_check(Music.current == -1 and not Music.is_playing(0), "silent to begin with")
	Music.play_track(0)
	_check(Music.current == 0 and Music.is_playing(0) and changes == [0], "play_track(0) starts the meadow and says so")
	await get_tree().create_timer(0.3).timeout
	var voice: AudioStreamPlayer = null
	for child in Music.get_children():
		if (child as AudioStreamPlayer).playing:
			voice = child
	var position_before: float = voice.get_playback_position()
	Music.play_track(0)
	await get_tree().create_timer(0.2).timeout
	_check(changes == [0] and voice.playing and voice.get_playback_position() > position_before,
		"asking for the same track again neither restarts nor re-announces it")
	Music.play_track(3)
	_check(Music.current == 3 and changes == [0, 3], "play_track(3) switches")
	_check(Music.is_playing(0) and Music.is_playing(3), "both sound during the crossfade")
	await _after_fade()
	_check(Music.is_playing(3) and not Music.is_playing(0), "and only the new one after it")
	var loud: AudioStreamPlayer = null
	for child in Music.get_children():
		if (child as AudioStreamPlayer).playing:
			loud = child
	_check(loud != null and absf(loud.volume_db - Music.VOLUME_DB) < 0.5, "at the music level (%.1f dB)" % (loud.volume_db if loud else -999.0))
	Music.play_track(99)
	_check(Music.current == 3, "an index out of range is refused, not crashed on")
	# A second switch inside the crossfade, back to the track fading out:
	# that voice fades back up rather than restarting, and the loud one is
	# faded, never cut.
	Music.play_track(5)
	await get_tree().create_timer(0.3).timeout
	var loud_before: AudioStreamPlayer = loud
	var pos_5 := 0.0
	for child in Music.get_children():
		if (child as AudioStreamPlayer).stream == Music._streams[5]:
			pos_5 = (child as AudioStreamPlayer).get_playback_position()
	Music.play_track(3)
	await get_tree().create_timer(0.2).timeout
	_check(Music.current == 3 and loud_before.playing and loud_before.stream == Music._streams[3] and loud_before.get_playback_position() > 0.5,
		"switching back inside the crossfade resumes the fading voice, unrestarted (pos %.2f)" % loud_before.get_playback_position())
	_check(Music.is_playing(5), "and the interrupted newcomer fades rather than being cut")
	await _after_fade()
	_check(Music.is_playing(3) and not Music.is_playing(5), "leaving only the track asked for last")
	Music.stop()
	_check(Music.current == -1 and changes.back() == -1, "stop() announces silence")
	await _after_fade()
	_check(not Music.is_playing(3), "and the loop has faded out")
	Settings.music_muted = true
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Music.BUS)), "Settings.music_muted mutes the bus")
	Settings.music_muted = false

	print("Wiring: the main menu, a level and the map")
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	add_child(menu)
	await _frames(2)
	_check(Music.current == 0, "the main menu plays the meadow")
	menu.free()
	GameState.pending_level_path = "res://data/levels/level_047.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _frames(2)
	_check(Music.current == 4, "level 47 plays track 4, '%s'" % Music.TRACKS[4]["title"])
	level.free()
	await _after_fade()
	var playing_voice: AudioStreamPlayer = null
	for child in Music.get_children():
		if (child as AudioStreamPlayer).playing:
			playing_voice = child
	var pos: float = playing_voice.get_playback_position()
	GameState.highest_unlocked_level = 48
	GameState.last_played_level_path = "res://data/levels/level_047.tres"
	var changes_before := changes.size()
	var map: Control = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(map)
	await _frames(3)
	await get_tree().create_timer(0.2).timeout # the mixer advances in ~20 ms steps; frames are faster headless
	var voices_playing := 0
	for child in Music.get_children():
		if (child as AudioStreamPlayer).playing:
			voices_playing += 1
	_check(Music.current == 4 and changes.size() == changes_before and voices_playing == 1
			and playing_voice.playing and playing_voice.get_playback_position() > pos,
		"back on the map it keeps playing, unrestarted: no track change announced, one voice, the same one (pos %.2f -> %.2f)"
		% [pos, playing_voice.get_playback_position()])
	map.free()
	GameState.last_played_level_path = ""
	GameState.highest_unlocked_level = 1
	map = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(map)
	await _frames(3)
	_check(Music.current == 0, "a fresh save's map plays the meadow")
	map.free()
	GameState.pending_level_path = "res://data/levels/tutorial_1.tres"
	level = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await _frames(2)
	_check(Music.current == 0, "a tutorial plays the meadow too")
	level.free()
	Music.stop()
	await _after_fade()

	Settings.music_muted = muted_before
	if _failures == 0:
		print("MUSIC PASS")
	else:
		printerr("MUSIC FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
