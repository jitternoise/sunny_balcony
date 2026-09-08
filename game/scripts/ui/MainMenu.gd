extends Control

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	continue_button.disabled = not _any_save_exists()


## Android's back button/gesture. This is the root screen, so back leaves
## the game -- the platform convention, and the one place Godot's old
## quit-on-back default was doing the right thing. Never reached on iOS.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		get_tree().quit()


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
