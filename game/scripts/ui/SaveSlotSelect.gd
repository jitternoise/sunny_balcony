extends Control

@onready var slot_container: VBoxContainer = $VBoxContainer
@onready var back_button: Button = $BackButton

## The Back button's offsets as authored in SaveSlotSelect.tscn, captured
## before any inset so _apply_safe_area() re-derives rather than accumulates.
var _base_back_offsets := Vector4.ZERO


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	_base_back_offsets = Vector4(
		back_button.offset_left, back_button.offset_top,
		back_button.offset_right, back_button.offset_bottom)
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_apply_safe_area):
		vp.size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_build_slot_buttons()


## Keeps the Back button clear of a notch or a status bar. The slot buttons
## themselves are centred in the screen, so nothing else here can collide
## with a cutout, and the sky/grass behind stays full-bleed.
func _apply_safe_area() -> void:
	var inset := SafeArea.insets(get_viewport())
	back_button.offset_left = _base_back_offsets.x + inset.x
	back_button.offset_top = _base_back_offsets.y + inset.y
	back_button.offset_right = _base_back_offsets.z + inset.x
	back_button.offset_bottom = _base_back_offsets.w + inset.y


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


## The slot whose reset has been armed by a first tap, or -1. A damaged slot
## is the one control here that destroys something, so it takes two taps:
## the first only relabels the button, the second goes through. Tapping any
## other slot disarms it again.
var _armed_reset_slot: int = -1


func _build_slot_buttons() -> void:
	for child in slot_container.get_children():
		slot_container.remove_child(child)
		child.queue_free()
	for slot in range(GameState.SAVE_SLOT_COUNT):
		var button := Button.new()
		# 96 viewport units. Under stretch/aspect=expand the 720-unit-wide
		# viewport maps onto the device's full width, so a unit is 0.5dp on a
		# 360dp phone and 0.57dp on a 411dp one -- 96 is therefore >=48dp
		# (Android's minimum touch target, and above Apple's 44pt) across the
		# mainstream handset range. Intrinsic height here was ~47 units, i.e.
		# ~24dp: half the minimum, on the screen that picks a save file.
		button.custom_minimum_size = Vector2(0, 96)
		button.text = _slot_label(slot)
		button.pressed.connect(_on_slot_selected.bind(slot))
		slot_container.add_child(button)


## A damaged slot must not read as "new game". That was the failure the save
## work fixed underneath: a save that could not be parsed left every progress
## field at its new-game default, the button said "(continue)" anyway, and
## the player's next win wrote the reset over the top. Naming it is the only
## way they can tell a corrupt save from a forgotten one.
func _slot_label(slot: int) -> String:
	if slot == _armed_reset_slot:
		return "Slot %d — tap again to reset" % (slot + 1)
	match GameState.slot_status(slot):
		GameState.SlotStatus.OK:
			return "Slot %d (continue)" % (slot + 1)
		GameState.SlotStatus.DAMAGED:
			return "Slot %d (damaged)" % (slot + 1)
		_:
			return "Slot %d (new game)" % (slot + 1)


func _refresh_slot_labels() -> void:
	for slot in range(GameState.SAVE_SLOT_COUNT):
		var button := slot_container.get_child(slot) as Button
		if button:
			button.text = _slot_label(slot)


func _on_slot_selected(slot: int) -> void:
	if GameState.slot_status(slot) == GameState.SlotStatus.DAMAGED:
		if _armed_reset_slot != slot:
			_armed_reset_slot = slot   # first tap: arm, and say so
			_refresh_slot_labels()
			return
		# Second tap on the same damaged slot: throw it away and start over.
		_armed_reset_slot = -1
		GameState.discard_damaged_slot(slot)
	elif _armed_reset_slot != -1:
		_armed_reset_slot = -1         # a different slot: disarm
		_refresh_slot_labels()

	var is_new := not GameState.slot_exists(slot)
	GameState.load_slot(slot)
	if is_new:
		GameState.save_current_slot() # create the file on disk immediately
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
