extends Node
# Autoload singleton (see [autoload] in project.godot).
# Player preferences that belong to the DEVICE rather than to a save slot:
# a mute and a volume each for the music and the sound effects, and how
# opaque the hex grid is drawn. Kept out of GameState on purpose -- a
# player who mutes the game wants it muted in every slot, and these must
# survive a slot being deleted.
#
# The audio settings act on the "Music" and "SFX" buses in
# default_bus_layout.tres, never on a player: the Music and Sfx autoloads
# only have to name their bus. A mute is the bus's mute flag; a volume is
# the bus's gain, on top of whatever level each player mixes at.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const SECTION_DISPLAY := "display"

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

## Fired whenever grid_opacity is set, so a board on screen can repaint with
## the new value while the player is still dragging the slider.
signal grid_opacity_changed(value: float)

var music_muted: bool = false:
	set(value):
		music_muted = value
		_apply_bus(BUS_MUSIC, value)
		_save()

var sfx_muted: bool = false:
	set(value):
		sfx_muted = value
		_apply_bus(BUS_SFX, value)
		_save()

## The bus gain for a volume of 0: as good as silent, without the -inf dB
## that linear_to_db(0) would give the bus.
const SILENT_VOLUME_DB := -60.0

## Music level, 0..1, as the player set it on the Options slider: applied
## to the Music bus as a gain (linear_to_db, so 0.5 is -6 dB) on top of
## Music.VOLUME_DB, which is the mix. Independent of music_muted -- the
## mute wins, and unmuting comes back at this level.
var music_volume: float = 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume(BUS_MUSIC, music_volume)
		_save()

## The same dial for the sound effects: the SFX bus's gain on top of the
## level each clip was synthesised at (tools/gen_sfx.py's PEAKS).
var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_volume(BUS_SFX, sfx_volume)
		_save()

## Alpha of an EMPTY cell's dark fill, 0..1. Terrain, blocks and water keep
## their own colours whatever this says -- they carry information -- and so
## does the cell border, so at 0 the grid is still there as an outline on
## the grass and the level stays playable. Read by HexBoard.empty_fill().
var grid_opacity: float = 1.0:
	set(value):
		grid_opacity = clampf(value, 0.0, 1.0)
		grid_opacity_changed.emit(grid_opacity)
		_save()


func _ready() -> void:
	_load()
	# Belt and braces for a first launch with no file, where _load() applied
	# nothing: the defaults match default_bus_layout.tres today, and this
	# keeps them in step if that layout ever drifts.
	_apply_bus(BUS_MUSIC, music_muted)
	_apply_bus(BUS_SFX, sfx_muted)
	_apply_volume(BUS_MUSIC, music_volume)
	_apply_volume(BUS_SFX, sfx_volume)


## Mutes or unmutes one bus. A missing bus -- the layout not loaded, or a
## renamed bus -- is a silent no-op rather than an index-out-of-range
## crash in the Options menu.
func _apply_bus(bus_name: String, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, muted)


## Sets one bus's gain from a 0..1 volume; same no-op on a missing bus.
func _apply_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(volume) if volume > 0.0 else SILENT_VOLUME_DB)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return # first launch, or unreadable: defaults are "everything on"
	# These go through the setters -- Godot 4 runs a property's set: on an
	# in-class assignment too; only the setter's own body writes the field
	# -- so a load applies each value to its bus, emits grid_opacity_changed
	# (nobody is listening yet at autoload time) and rewrites the file once
	# per field, which is how a file from before a new key gains it. The
	# _apply_* calls in _ready() only matter on a first launch with no file.
	music_muted = bool(config.get_value(SECTION, "music_muted", false))
	sfx_muted = bool(config.get_value(SECTION, "sfx_muted", false))
	music_volume = clampf(float(config.get_value(SECTION, "music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION, "sfx_volume", 1.0)), 0.0, 1.0)
	grid_opacity = clampf(float(config.get_value(SECTION_DISPLAY, "grid_opacity", 1.0)), 0.0, 1.0)


## Small and rewritten whole. Unlike a save there is nothing here that
## cannot be re-chosen in two taps, so it does not need the temp-and-rename
## dance GameState.save_current_slot() goes through.
func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_muted", music_muted)
	config.set_value(SECTION, "sfx_muted", sfx_muted)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION_DISPLAY, "grid_opacity", grid_opacity)
	config.save(SETTINGS_PATH)
