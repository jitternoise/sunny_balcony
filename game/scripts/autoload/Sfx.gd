extends Node
# Autoload singleton (see [autoload] in project.godot).
#
# Every sound effect in the game, by name, and the one place that plays
# them. The catalogue below is the single source of truth: a sound is a
# name here, a .wav of that name under SFX_DIR (synthesised by
# tools/gen_sfx.py -- nothing is recorded), and the play() calls that use
# it. tests/VerifySfx.tscn fails the moment those three disagree, so a
# sound cannot be half-added or half-removed.
#
# Adding a sound (its name is lowercase letters, digits and underscores --
# it is the file name too):
#   1. a recipe in tools/gen_sfx.py, under the same name; run it
#   2. `godot --headless --import --path game` so the .wav gets its .import
#   3. an entry in SOUNDS below
#   4. Sfx.play(&"name") from presentation code -- Level.gd, a UI script.
#      Never from HexBoard.gd: it is the simulation, and it is compiled by
#      tools/verify_solutions.gd under --script where no autoload exists
#      (see CLAUDE.md). The board emits a signal; Level.gd plays the sound.
# Removing one: the reverse of all four. Leave a play() behind and the
# game warns once and stays silent; VerifySfx catches it before that.
#
# Playback goes through VOICES AudioStreamPlayers on the "SFX" bus, which
# Settings.sfx_muted mutes, so muting needs nothing here. The same name
# asked for twice inside REPEAT_WINDOW_MSEC plays once: a beat that puts
# out three fires or fills three lake cells makes one sound, not a chord.

const SFX_DIR := "res://assets/sfx/"
const BUS := "SFX"

## What every hooked button plays -- see hook_buttons().
const TAP_SOUND := &"ui_tap"
const VOICES := 8
const REPEAT_WINDOW_MSEC := 60
const HISTORY_MAX := 64

## The catalogue. `when` says what the sound is for; `vary` is a random
## pitch spread (+-) applied on each play, so a sound heard fifty times a
## level does not read as a loop.
const SOUNDS: Dictionary = {
	&"ui_tap":    {"when": "any button, toggle or level node", "vary": 0.0},
	&"place":     {"when": "a block set down on the board", "vary": 0.05},
	&"pickup":    {"when": "a block lifted off the board again", "vary": 0.05},
	&"invalid":   {"when": "a tap the board refused (occupied, off-grid, no inventory)", "vary": 0.0},
	&"start":     {"when": "Start pressed: the flood released", "vary": 0.0},
	&"drop":      {"when": "a WATER beat on which the flood moved", "vary": 0.12},
	&"pool_fill": {"when": "a drop landing in a lake", "vary": 0.08},
	&"pool_full": {"when": "a lake reaching full", "vary": 0.0},
	&"fire_out":  {"when": "a fire put out", "vary": 0.04},
	&"geyser":    {"when": "a geyser waking into a second source", "vary": 0.0},
	&"hydro":     {"when": "a Hydro Plant spinning up", "vary": 0.0},
	&"dig":       {"when": "water cutting through dirt", "vary": 0.08},
	&"blast":     {"when": "a Bomb Catapult's charge going off", "vary": 0.03},
	&"splash":    {"when": "water lost over the bottom edge", "vary": 0.0},
	&"win":       {"when": "the level won", "vary": 0.0},
	&"lose":      {"when": "the level lost, whatever the reason", "vary": 0.0},
	&"pause":     {"when": "the pause menu opening", "vary": 0.0},
	&"resume":    {"when": "the pause menu closing", "vary": 0.0},
}

## Fired after a sound actually starts (not for a throttled repeat or an
## unknown name). Tests listen to this; nothing in the game needs to.
signal played(sound: StringName)

## The last HISTORY_MAX sounds that actually started, oldest first.
var history: Array[StringName] = []

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_started: Dictionary = {}
var _warned: Dictionary = {}


func _ready() -> void:
	for sound in SOUNDS:
		var path := SFX_DIR + String(sound) + ".wav"
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if stream == null:
			push_warning("Sfx: no stream for %s at %s -- it will be silent" % [sound, path])
		_streams[sound] = stream
	for i in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = BUS
		add_child(player)
		_players.append(player)


## Silences every voice.
func stop_all() -> void:
	for player in _players:
		player.stop()


## On the way out of the tree (a quit), give the mixer thread a moment to
## let go of any sound still playing. A stop is not immediate: the mixer
## fades the playback out over its next step and only then deletes it, and
## AudioServer.finish() does not clean up what is left -- so a quit
## mid-sound (the main menu's Quit after its click; every headless test
## that ends on a win jingle) reported the playback and its stream as
## leaked objects at exit. The voices have already stopped themselves by
## the time this runs -- a child leaves the tree before its parent, and an
## AudioStreamPlayer stops on the way out -- so this only has to wait, and
## only when a sound could still be fading: within the longest clip of the
## last start. EXIT_DRAIN_MSEC is a few mixer steps; nothing is drawn in it.
const EXIT_DRAIN_MSEC := 80
const LONGEST_CLIP_MSEC := 3000

var _last_any_started: int = -LONGEST_CLIP_MSEC


func _exit_tree() -> void:
	stop_all()
	if Time.get_ticks_msec() - _last_any_started < LONGEST_CLIP_MSEC:
		OS.delay_msec(EXIT_DRAIN_MSEC)


## Plays `sound` on the next free voice. Returns true if it started, false
## if it was throttled as a repeat, has no stream, or is not in SOUNDS
## (which warns once per name -- a typo, or a sound that was removed).
## `volume_db` nudges one call, e.g. a quieter drop for a small level.
func play(sound: StringName, volume_db: float = 0.0) -> bool:
	if not SOUNDS.has(sound):
		if not _warned.has(sound):
			_warned[sound] = true
			push_warning("Sfx: unknown sound %s -- not in Sfx.SOUNDS" % sound)
		return false
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_started.get(sound, -REPEAT_WINDOW_MSEC)) < REPEAT_WINDOW_MSEC:
		return false
	_last_started[sound] = now
	_last_any_started = now

	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	var vary: float = SOUNDS[sound]["vary"]
	player.pitch_scale = 1.0 + randf_range(-vary, vary) if vary > 0.0 else 1.0
	player.play()

	history.append(sound)
	if history.size() > HISTORY_MAX:
		history.pop_front()
	played.emit(sound)
	return true


## Gives every button under `root` the ui_tap sound on press, except the
## ones named in `except` (buttons with a sound of their own -- Start,
## Pause, Resume). Safe to call again after more buttons are added: a
## button already hooked is skipped. Call it from a screen's _ready() and
## again wherever that screen builds buttons at runtime.
func hook_buttons(root: Node, except: Array[StringName] = []) -> int:
	var hooked := 0
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if except.has(button.name) or button.pressed.is_connected(_on_hooked_button):
			continue
		button.pressed.connect(_on_hooked_button)
		hooked += 1
	if root is BaseButton and not except.has(root.name) \
			and not (root as BaseButton).pressed.is_connected(_on_hooked_button):
		(root as BaseButton).pressed.connect(_on_hooked_button)
		hooked += 1
	return hooked


func _on_hooked_button() -> void:
	play(TAP_SOUND)


## Plays `sound` after `seconds` -- a jingle that should follow a splash
## rather than land on it. The timer lives on the SceneTree, so it survives
## the scene that asked for it changing. Not throttled until it plays.
func play_after(sound: StringName, seconds: float) -> void:
	if not SOUNDS.has(sound):
		play(sound) # warns once, same as an immediate unknown name
		return
	get_tree().create_timer(seconds).timeout.connect(play.bind(sound))


## Whether `sound` is still ringing on any voice. For tests and for anything
## that must not stack a long sound on itself.
func is_playing(sound: StringName) -> bool:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return false
	for player in _players:
		if player.playing and player.stream == stream:
			return true
	return false
