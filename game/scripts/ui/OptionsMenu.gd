extends Control
class_name OptionsMenu

## The Options popup: mute the music and set its volume, mute the sound
## effects, thin the hex grid. One scene, instanced on the main menu, on Level Select and inside
## a level's pause menu, so the three never drift apart. It is a modal like
## the level's popups: the root and the Dim rect both STOP mouse input, so
## a tap beside the panel cannot reach whatever is underneath -- on Level
## Select that would be a level node, in a level the board.
##
## The toggles read "Music" / "Sound effects" and are ON when audible, so a
## player scanning the panel sees what is on rather than what is muted.
## They write straight to Settings, which persists them and mutes the bus;
## nothing here is applied on Close, so there is no Cancel to get wrong.
##
## The two sliders -- music volume, grid opacity -- run 0-100% in steps of
## 5 and write to Settings the same way, on every change: the music bus
## and the board behind the pause menu follow the thumb as it moves, and
## the 5% step bounds a full sweep to twenty small settings writes rather
## than one per frame of the drag.

signal closed

const SLIDER_MAX := 100.0

@onready var music_toggle: CheckButton = $Center/Panel/VBox/MusicToggle
@onready var music_volume_slider: HSlider = $Center/Panel/VBox/MusicVolumeSlider
@onready var music_volume_value: Label = $Center/Panel/VBox/MusicVolumeRow/MusicVolumeValue
@onready var sfx_toggle: CheckButton = $Center/Panel/VBox/SfxToggle
@onready var grid_opacity_slider: HSlider = $Center/Panel/VBox/GridOpacitySlider
@onready var grid_opacity_value: Label = $Center/Panel/VBox/GridOpacityRow/GridOpacityValue
@onready var close_button: Button = $Center/Panel/VBox/CloseButton


func _ready() -> void:
	music_toggle.toggled.connect(func(on: bool): Settings.music_muted = not on)
	sfx_toggle.toggled.connect(func(on: bool): Settings.sfx_muted = not on)
	music_volume_slider.value_changed.connect(_on_music_volume_slider_changed)
	grid_opacity_slider.value_changed.connect(_on_grid_opacity_slider_changed)
	close_button.pressed.connect(close)
	# The toggles and Close click like every other button. The SFX toggle's
	# own click lands after the write, so switching sound off is silent and
	# switching it on is the first thing heard -- the conventional feel.
	Sfx.hook_buttons(self)


func _on_music_volume_slider_changed(value: float) -> void:
	Settings.music_volume = value / SLIDER_MAX
	_show_percent(music_volume_value, value)


func _on_grid_opacity_slider_changed(value: float) -> void:
	Settings.grid_opacity = value / SLIDER_MAX
	_show_percent(grid_opacity_value, value)


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
	music_volume_slider.set_value_no_signal(Settings.music_volume * SLIDER_MAX)
	_show_percent(music_volume_value, music_volume_slider.value)
	grid_opacity_slider.set_value_no_signal(Settings.grid_opacity * SLIDER_MAX)
	_show_percent(grid_opacity_value, grid_opacity_slider.value)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
