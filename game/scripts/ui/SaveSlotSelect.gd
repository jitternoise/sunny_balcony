extends Control

@onready var slot_container: VBoxContainer = $VBoxContainer
@onready var back_button: Button = $BackButton

## The sticker a save file can earn by finishing every side-path level.
## Drawn on every slot, greyed until earned, so the player sees from the
## first screen that there is something to collect -- the same reason a
## locked spur is still drawn on the map.
const ICON_STICKER := preload("res://assets/icons/ui_sticker.svg")
const STICKER_SIZE := 64.0
const STICKER_LOCKED_TINT := Color(0.35, 0.35, 0.35, 0.55)
const SLOT_HEIGHT := 120.0 # two lines of text plus the sticker, all >=48dp

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
	Sfx.hook_buttons(self)


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
		slot_container.add_child(_build_slot_button(slot))


## One slot: a wide button carrying two lines of text -- the slot's name
## and state on the first, its progress on the second -- with the sticker
## on the right. The text lives in Labels rather than the button's own
## `text` so the two lines can differ in size; every child ignores the
## mouse, so the whole rectangle is the button.
##
## The SLOT_HEIGHT is viewport units. Under stretch/aspect=expand the
## 720-unit-wide viewport maps onto the device's full width, so a unit is
## 0.5dp on a 360dp phone -- 96 is the 48dp floor (Android's minimum touch
## target, above Apple's 44pt), and 120 leaves room for the second line.
func _build_slot_button(slot: int) -> Button:
	var button := Button.new()
	button.name = "slot_%d" % slot
	button.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	button.pressed.connect(_on_slot_selected.bind(slot))

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24.0
	row.offset_right = -20.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	button.add_child(row)

	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 2)
	row.add_child(lines)

	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(title)

	var progress := Label.new()
	progress.name = "Progress"
	progress.add_theme_font_size_override("font_size", 14)
	progress.modulate = Color(1, 1, 1, 0.85)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(progress)

	var sticker := TextureRect.new()
	sticker.name = "Sticker"
	sticker.texture = ICON_STICKER
	sticker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sticker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sticker.custom_minimum_size = Vector2(STICKER_SIZE, STICKER_SIZE)
	sticker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sticker)

	_refresh_slot(slot, button)
	return button


## Fills one slot's text and sticker from what is on disk.
func _refresh_slot(slot: int, button: Button) -> void:
	var parsed = GameState.peek_slot(slot)
	button.get_node("Row/Lines/Title").text = _slot_label(slot)
	button.get_node("Row/Lines/Progress").text = _progress_line(slot, parsed)
	var sticker: TextureRect = button.get_node("Row/Sticker")
	var earned: bool = parsed != null and GameState.side_path_complete_in(parsed)
	sticker.modulate = Color.WHITE if earned else STICKER_LOCKED_TINT
	button.tooltip_text = ("Side-path sticker earned" if earned
		else "Sticker: finish every side path to earn it")


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


## The second line: how far the file has got. Under developer mode every
## level is open regardless of the file, so a "furthest level" would be a
## lie -- the line says that instead, on every slot, so nobody reads a
## test session's progress as their own.
func _progress_line(slot: int, parsed) -> String:
	if GameState.debug_unlock_all:
		return "Developer mode — all levels unlocked"
	if parsed == null:
		if GameState.slot_status(slot) == GameState.SlotStatus.DAMAGED:
			return "Save could not be read"
		return "No progress yet"
	if GameState.campaign_complete_in(parsed):
		return "All 100 levels complete"
	return "Furthest level: %d" % GameState.furthest_level_in(parsed)


func _refresh_slot_labels() -> void:
	for slot in range(GameState.SAVE_SLOT_COUNT):
		var button := slot_container.get_child(slot) as Button
		if button:
			_refresh_slot(slot, button)


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
