extends Node
# Autoload singleton (see [autoload] in project.godot).
# Player preferences that belong to the DEVICE rather than to a save slot:
# muting the music and muting the sound effects. Kept out of GameState on
# purpose -- a player who mutes the game wants it muted in every slot, and
# these must survive a slot being deleted.
#
# There is no audio in the project yet. The two flags drive the "Music" and
# "SFX" buses in default_bus_layout.tres, so when audio arrives every
# AudioStreamPlayer just has to name its bus and the Options menu already
# controls it. Nothing here needs to change.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

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


## Small and rewritten whole. Unlike a save there is nothing here that
## cannot be re-chosen in two taps, so it does not need the temp-and-rename
## dance GameState.save_current_slot() goes through.
func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_muted", music_muted)
	config.set_value(SECTION, "sfx_muted", sfx_muted)
	config.save(SETTINGS_PATH)
