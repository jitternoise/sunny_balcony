extends Control

@onready var slot_container: VBoxContainer = $VBoxContainer
@onready var back_button: Button = $BackButton


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	_build_slot_buttons()


## The Back button's destination, pulled out of the old inline lambda so the
## Android Back handler below can reuse it -- the two must always agree.
func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## Android's hardware/gesture Back. See MainMenu.gd's _notification() for why
## the engine's own quit_on_go_back handling is switched off project-wide.
## Never fires on iOS.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


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
