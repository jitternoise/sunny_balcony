extends Control

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# iOS ships no user-facing "quit the app" affordance: Apple's HIG treats
	# programmatic termination as indistinguishable from a crash, and a visible
	# Quit button is a routine App Store review rejection. Android (and desktop,
	# for editor testing) keeps it. _on_quit_pressed() and the Back handler
	# below are the only get_tree().quit() calls in the project, and neither is
	# reachable on iOS once this button is hidden -- Back doesn't exist there.
	quit_button.visible = not OS.has_feature("ios")

	continue_button.disabled = not _any_save_exists()


func _any_save_exists() -> bool:
	for slot in range(GameState.SAVE_SLOT_COUNT):
		if GameState.slot_exists(slot):
			return true
	return false


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SaveSlotSelect.tscn")


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SaveSlotSelect.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


## Android's hardware/gesture Back button. project.godot sets
## application/config/quit_on_go_back=false so the engine no longer kills the
## app the instant Back is pressed on ANY screen; each scene routes it to its
## own Back destination instead (see the matching _notification() in
## SaveSlotSelect.gd, LevelSelect.gd and Level.gd). The main menu is the top of
## the navigation stack, so here Back really does mean "leave the game" -- the
## one screen where the old engine default happened to be correct.
##
## Never fires on iOS: there is no system back event to receive.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_quit_pressed()
