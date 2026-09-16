extends Control
class_name OptionsMenu

## The Options popup: mute the music, mute the sound effects. One scene,
## instanced on the main menu, on Level Select and inside a level's pause
## menu, so the three never drift apart. It is a modal like the level's
## popups: the root and the Dim rect both STOP mouse input, so a tap beside
## the panel cannot reach whatever is underneath -- on Level Select that
## would be a level node, in a level the board.
##
## The toggles read "Music" / "Sound effects" and are ON when audible, so a
## player scanning the panel sees what is on rather than what is muted.
## They write straight to Settings, which persists them and mutes the bus;
## nothing here is applied on Close, so there is no Cancel to get wrong.

signal closed

@onready var music_toggle: CheckButton = $Center/Panel/VBox/MusicToggle
@onready var sfx_toggle: CheckButton = $Center/Panel/VBox/SfxToggle
@onready var close_button: Button = $Center/Panel/VBox/CloseButton


func _ready() -> void:
	music_toggle.toggled.connect(func(on: bool): Settings.music_muted = not on)
	sfx_toggle.toggled.connect(func(on: bool): Settings.sfx_muted = not on)
	close_button.pressed.connect(close)


## Shows the panel with the toggles reflecting the live settings. Read on
## every open rather than once in _ready(): the main menu's instance is
## built before a level's could change anything, but a scene that lives a
## long time -- Level Select -- should still show the truth.
func open() -> void:
	# set_pressed_no_signal: setting button_pressed would fire toggled and
	# re-save the value that was just read.
	music_toggle.set_pressed_no_signal(not Settings.music_muted)
	sfx_toggle.set_pressed_no_signal(not Settings.sfx_muted)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
