extends Node
# Autoload singleton (see [autoload] in project.godot).
#
# Background music: one loop per ten levels, the same ten bands as the
# backdrops (Backdrop.PALETTES), so the music changes where the sky does.
# TRACKS is the catalogue -- index = Backdrop palette index -- and each
# file is assets/music/<name>.wav, composed by tools/gen_music.py (nothing
# is recorded). tests/VerifyMusic.tscn fails when the catalogue, the
# directory, the songs in the generator and the palettes disagree.
#
# Who plays what: a level plays its own band (Level._ready); the map plays
# the band of the level it opens on (LevelSelect._build_map); the main menu
# plays the meadow. Asking for the band already playing does nothing, so
# going from the map into a level of the same band -- or on to the next
# level -- never restarts the loop; a change crossfades over CROSSFADE_SEC.
# Two voices on the "Music" bus, which Settings.music_muted mutes.
#
# Adding a track (a new band): a palette in Backdrop.PALETTES, a SONG in
# tools/gen_music.py (run it, then `godot --headless --import --path game`,
# then set edit/loop_mode=2 -- Forward; 1 is Disabled, and 0 "detect" is
# Disabled too for a WAV without loop markers -- in the new .import and
# import again), and an entry here in the same position. Changing a
# track: edit its SONG, run the generator, import; the .import keeps its
# loop flag.

const MUSIC_DIR := "res://assets/music/"
const BUS := "Music"
const VOLUME_DB := -8.0
const SILENT_DB := -60.0
const CROSSFADE_SEC := 1.5

## One entry per ten levels, in Backdrop.PALETTES order: the file's name
## under MUSIC_DIR and a title for the credits.
const TRACKS: Array[Dictionary] = [
	{"file": "01_spring_meadow", "title": "Spring Meadow"},
	{"file": "02_deep_valley", "title": "Deep Valley"},
	{"file": "03_morning_riverbank", "title": "Morning Riverbank"},
	{"file": "04_dry_season", "title": "Dry Season"},
	{"file": "05_evening_pines", "title": "Evening Pines"},
	{"file": "06_golden_plains", "title": "Golden Plains"},
	{"file": "07_geyser_country", "title": "Geyser Country"},
	{"file": "08_badger_dusk", "title": "Badger Dusk"},
	{"file": "09_jamboree_sunset", "title": "Jamboree Sunset"},
	{"file": "10_the_pan", "title": "The Pan"},
]

## Fired when a different track starts (not when the same one is asked for
## again). -1 means the music stopped.
signal track_changed(index: int)

## The track playing now, an index into TRACKS, or -1 for none.
var current: int = -1

var _streams: Array[AudioStream] = []
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _fades: Array[Tween] = [null, null]


func _ready() -> void:
	for track in TRACKS:
		var path := MUSIC_DIR + String(track["file"]) + ".wav"
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if stream == null:
			push_warning("Music: no stream for %s at %s -- that band will be silent" % [track["title"], path])
		elif stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			# A fallback, not the plan: the .import should say
			# edit/loop_mode=2 (VerifyMusic checks the file itself). If a
			# fresh import wrote the default 0, loop the whole file anyway
			# rather than play it once and fall silent.
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_streams.append(stream)
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


## The track for a level id -- the same band as its backdrop.
static func track_for_level(level_id: int) -> int:
	return Backdrop.index_for_level(level_id)


func play_for_level(level_id: int) -> void:
	play_track(track_for_level(level_id))


## Starts TRACKS[index], crossfading from whatever is playing. Asking for
## the track already playing is a no-op, so the loop is never restarted by
## a scene that happens to be in the same band.
func play_track(index: int) -> void:
	if index < 0 or index >= TRACKS.size():
		push_warning("Music: no track %d" % index)
		return
	if index == current:
		return
	var stream: AudioStream = _streams[index]
	current = index
	_last_change_msec = Time.get_ticks_msec()
	if stream == null:
		_fade_out(_players[_active])
		track_changed.emit(index)
		return

	# Which voice takes the new track. If the track is still sounding on a
	# voice that is fading out (A -> B -> A inside one crossfade), that
	# voice simply fades back up: no reassignment, no restart. Otherwise a
	# voice that is silent, else the quieter one -- never the loud one, or
	# a second switch inside the fade would cut the outgoing loop dead.
	var slot := -1
	for i in range(_players.size()):
		if _players[i].playing and _players[i].stream == stream:
			slot = i
	var resuming := slot != -1
	if slot == -1:
		for i in range(_players.size()):
			if not _players[i].playing:
				slot = i
	if slot == -1:
		slot = 0 if _players[0].volume_db <= _players[1].volume_db else 1
	var outgoing: AudioStreamPlayer = _players[1 - slot]
	_active = slot
	var incoming: AudioStreamPlayer = _players[slot]
	_kill_fade(slot)
	if not resuming:
		incoming.stream = stream
		incoming.volume_db = SILENT_DB
		incoming.play()
	# Faded in linear amplitude, not dB: a dB-linear tween spends most of
	# the crossfade with both voices 20-30 dB down -- a hole, not a blend.
	_fades[slot] = create_tween()
	_fades[slot].tween_property(incoming, "volume_linear", db_to_linear(VOLUME_DB), CROSSFADE_SEC)
	_fade_out(outgoing)
	track_changed.emit(index)


## Fades the music out and stops it. The next play_track() starts afresh.
func stop() -> void:
	if current == -1:
		return
	current = -1
	_last_change_msec = Time.get_ticks_msec()
	_fade_out(_players[_active])
	track_changed.emit(-1)


## Whether a voice is sounding TRACKS[index] right now (fading out counts
## until it has stopped).
func is_playing(index: int) -> bool:
	if index < 0 or index >= _streams.size() or _streams[index] == null:
		return false
	for player in _players:
		if player.playing and player.stream == _streams[index]:
			return true
	return false


func _fade_out(player: AudioStreamPlayer) -> void:
	var slot := _players.find(player)
	_kill_fade(slot)
	if not player.playing:
		return
	_fades[slot] = create_tween()
	# To the silent floor rather than 0.0, which would park volume_db at
	# -inf on the voice.
	_fades[slot].tween_property(player, "volume_linear", db_to_linear(SILENT_DB), CROSSFADE_SEC)
	_fades[slot].tween_callback(player.stop)


func _kill_fade(slot: int) -> void:
	if _fades[slot] != null and _fades[slot].is_valid():
		_fades[slot].kill()
	_fades[slot] = null


## On the way out of the tree (a quit), give the mixer a moment to let go
## of a playing loop, or the quit reports its playback as leaked -- see
## Sfx._exit_tree() for the why. The voices have already stopped
## themselves by now (a child leaves the tree before its parent), so this
## cannot ask them whether they were playing; it waits whenever a track is
## current or one was stopped within the last fade. The length is
## Sfx.EXIT_DRAIN_MSEC's, for the same reason.
const EXIT_DRAIN_MSEC := 250

var _last_change_msec: int = -100000


func _exit_tree() -> void:
	for player in _players:
		player.stop()
	var fading := Time.get_ticks_msec() - _last_change_msec < int((CROSSFADE_SEC + 0.5) * 1000.0)
	if current != -1 or fading:
		OS.delay_msec(EXIT_DRAIN_MSEC)
