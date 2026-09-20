extends Node
# Autoload singleton (see [autoload] in project.godot).
# Player preferences that belong to the DEVICE rather than to a save slot:
# muting the music, muting the sound effects, and how opaque the hex grid
# is drawn. Kept out of GameState on purpose -- a player who mutes the game
# wants it muted in every slot, and these must survive a slot being deleted.
#
# There is no audio in the project yet. The two flags drive the "Music" and
# "SFX" buses in default_bus_layout.tres, so when audio arrives every
# AudioStreamPlayer just has to name its bus and the Options menu already
# controls it. Nothing here needs to change.

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
	_apply_bus(BUS_MUSIC, music_muted)
	_apply_bus(BUS_SFX, sfx_muted)


## Mutes or unmutes one bus. A missing bus -- the layout not loaded, or a
## renamed bus -- is a silent no-op rather than an index-out-of-range
## crash in the Options menu.
func _apply_bus(bus_name: String, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, muted)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return # first launch, or unreadable: defaults are "everything on"
	# Straight to the fields, not through the setters: a load must not
	# write the file back or touch the buses before _ready() applies them.
	music_muted = bool(config.get_value(SECTION, "music_muted", false))
	sfx_muted = bool(config.get_value(SECTION, "sfx_muted", false))
	grid_opacity = clampf(float(config.get_value(SECTION_DISPLAY, "grid_opacity", 1.0)), 0.0, 1.0)


## Small and rewritten whole. Unlike a save there is nothing here that
## cannot be re-chosen in two taps, so it does not need the temp-and-rename
## dance GameState.save_current_slot() goes through.
func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_muted", music_muted)
	config.set_value(SECTION, "sfx_muted", sfx_muted)
	config.set_value(SECTION_DISPLAY, "grid_opacity", grid_opacity)
	config.save(SETTINGS_PATH)
