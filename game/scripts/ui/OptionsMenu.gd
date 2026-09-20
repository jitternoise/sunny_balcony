extends Control
class_name OptionsMenu

## The Options popup: a mute and a volume each for the music and the sound
## effects, and the hex grid's opacity. One scene, instanced on the main
## menu, on Level Select and inside a level's pause menu, so the three
## never drift apart. It is a modal like
## the level's popups: the root and the Dim rect both STOP mouse input, so
## a tap beside the panel cannot reach whatever is underneath -- on Level
## Select that would be a level node, in a level the board.
##
## The toggles read "Music" / "Sound effects" and are ON when audible, so a
## player scanning the panel sees what is on rather than what is muted.
## They write straight to Settings, which persists them and mutes the bus;
## nothing here is applied on Close, so there is no Cancel to get wrong.
##
## The sliders -- music volume, effects volume, grid opacity -- run 0-100%
## in steps of 5 and write to Settings the same way, on every change: the
## bus, or the board behind the pause menu, follows the thumb as it moves,
## and the 5% step bounds a full sweep to twenty small settings writes
## rather than one per frame of the drag. Each is one row in _sliders --
## the slider, its percentage label and the Settings property it dials --
## built in _ready() because the entries are @onready nodes.

signal closed

const SLIDER_MAX := 100.0

@onready var music_toggle: CheckButton = $Center/Panel/VBox/MusicToggle
@onready var music_volume_slider: HSlider = $Center/Panel/VBox/MusicVolumeSlider
@onready var music_volume_value: Label = $Center/Panel/VBox/MusicVolumeRow/MusicVolumeValue
@onready var sfx_toggle: CheckButton = $Center/Panel/VBox/SfxToggle
@onready var sfx_volume_slider: HSlider = $Center/Panel/VBox/SfxVolumeSlider
@onready var sfx_volume_value: Label = $Center/Panel/VBox/SfxVolumeRow/SfxVolumeValue
@onready var grid_opacity_slider: HSlider = $Center/Panel/VBox/GridOpacitySlider
@onready var grid_opacity_value: Label = $Center/Panel/VBox/GridOpacityRow/GridOpacityValue
@onready var close_button: Button = $Center/Panel/VBox/CloseButton

## [slider, percentage label, Settings property] per dial, filled in _ready().
var _sliders: Array = []


func _ready() -> void:
	music_toggle.toggled.connect(func(on: bool): Settings.music_muted = not on)
	sfx_toggle.toggled.connect(func(on: bool): Settings.sfx_muted = not on)
	_sliders = [
		[music_volume_slider, music_volume_value, &"music_volume"],
		[sfx_volume_slider, sfx_volume_value, &"sfx_volume"],
		[grid_opacity_slider, grid_opacity_value, &"grid_opacity"],
	]
	for entry in _sliders:
		var slider: HSlider = entry[0]
		var label: Label = entry[1]
		var setting: StringName = entry[2]
		slider.value_changed.connect(func(value: float):
			Settings.set(setting, value / SLIDER_MAX)
			_show_percent(label, value))
	close_button.pressed.connect(close)
	# The toggles and Close click like every other button. The SFX toggle's
	# own click lands after the write, so switching sound off is silent and
	# switching it on is the first thing heard -- the conventional feel.
	Sfx.hook_buttons(self)


func _show_percent(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value)


## Shows the panel with the toggles reflecting the live settings. Read on
## every open rather than once in _ready(): the main menu's instance is
## built before a level's could change anything, but a scene that lives a
## long time -- Level Select -- should still show the truth.
func open() -> void:
	# set_pressed_no_signal: setting button_pressed would fire toggled and
	# re-save the value that was just read.
	music_toggle.set_pressed_no_signal(not Settings.music_muted)
	sfx_toggle.set_pressed_no_signal(not Settings.sfx_muted)
	# set_value_no_signal for the same reason; the labels are refreshed by
	# hand since nothing fires.
	for entry in _sliders:
		var slider: HSlider = entry[0]
		slider.set_value_no_signal(float(Settings.get(entry[2])) * SLIDER_MAX)
		_show_percent(entry[1], slider.value)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
