extends Control

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

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
