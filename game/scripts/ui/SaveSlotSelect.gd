extends Control

@onready var slot_container: VBoxContainer = $VBoxContainer
@onready var back_button: Button = $BackButton


func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_build_slot_buttons()


func _build_slot_buttons() -> void:
	for slot in range(GameState.SAVE_SLOT_COUNT):
		var button := Button.new()
		if GameState.slot_exists(slot):
			button.text = "Slot %d (continue)" % (slot + 1)
		else:
			button.text = "Slot %d (new game)" % (slot + 1)
		button.pressed.connect(_on_slot_selected.bind(slot))
		slot_container.add_child(button)


func _on_slot_selected(slot: int) -> void:
	var is_new := not GameState.slot_exists(slot)
	GameState.load_slot(slot)
	if is_new:
		GameState.save_current_slot() # create the file on disk immediately
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
