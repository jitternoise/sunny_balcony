extends Control
class_name LevelSelect

## Ordered list of every level's data resource -- the single source of truth
## for level order/count. All 100 campaign levels are authored.
const LEVEL_PATHS: Array[String] = [
	"res://data/levels/level_001.tres",
	"res://data/levels/level_002.tres",
	"res://data/levels/level_003.tres",
	"res://data/levels/level_004.tres",
	"res://data/levels/level_005.tres",
	"res://data/levels/level_006.tres",
	"res://data/levels/level_007.tres",
	"res://data/levels/level_008.tres",
	"res://data/levels/level_009.tres",
	"res://data/levels/level_010.tres",
	"res://data/levels/level_011.tres",
	"res://data/levels/level_012.tres",
	"res://data/levels/level_013.tres",
	"res://data/levels/level_014.tres",
	"res://data/levels/level_015.tres",
	"res://data/levels/level_016.tres",
	"res://data/levels/level_017.tres",
	"res://data/levels/level_018.tres",
	"res://data/levels/level_019.tres",
	"res://data/levels/level_020.tres",
	"res://data/levels/level_021.tres",
	"res://data/levels/level_022.tres",
	"res://data/levels/level_023.tres",
	"res://data/levels/level_024.tres",
	"res://data/levels/level_025.tres",
	"res://data/levels/level_026.tres",
	"res://data/levels/level_027.tres",
	"res://data/levels/level_028.tres",
	"res://data/levels/level_029.tres",
	"res://data/levels/level_030.tres",
	"res://data/levels/level_031.tres",
	"res://data/levels/level_032.tres",
	"res://data/levels/level_033.tres",
	"res://data/levels/level_034.tres",
	"res://data/levels/level_035.tres",
	"res://data/levels/level_036.tres",
	"res://data/levels/level_037.tres",
	"res://data/levels/level_038.tres",
	"res://data/levels/level_039.tres",
	"res://data/levels/level_040.tres",
	"res://data/levels/level_041.tres",
	"res://data/levels/level_042.tres",
	"res://data/levels/level_043.tres",
	"res://data/levels/level_044.tres",
	"res://data/levels/level_045.tres",
	"res://data/levels/level_046.tres",
	"res://data/levels/level_047.tres",
	"res://data/levels/level_048.tres",
	"res://data/levels/level_049.tres",
	"res://data/levels/level_050.tres",
	"res://data/levels/level_051.tres",
	"res://data/levels/level_052.tres",
	"res://data/levels/level_053.tres",
	"res://data/levels/level_054.tres",
	"res://data/levels/level_055.tres",
	"res://data/levels/level_056.tres",
	"res://data/levels/level_057.tres",
	"res://data/levels/level_058.tres",
	"res://data/levels/level_059.tres",
	"res://data/levels/level_060.tres",
	"res://data/levels/level_061.tres",
	"res://data/levels/level_062.tres",
	"res://data/levels/level_063.tres",
	"res://data/levels/level_064.tres",
	"res://data/levels/level_065.tres",
	"res://data/levels/level_066.tres",
	"res://data/levels/level_067.tres",
	"res://data/levels/level_068.tres",
	"res://data/levels/level_069.tres",
	"res://data/levels/level_070.tres",
	"res://data/levels/level_071.tres",
	"res://data/levels/level_072.tres",
	"res://data/levels/level_073.tres",
	"res://data/levels/level_074.tres",
	"res://data/levels/level_075.tres",
	"res://data/levels/level_076.tres",
	"res://data/levels/level_077.tres",
	"res://data/levels/level_078.tres",
	"res://data/levels/level_079.tres",
	"res://data/levels/level_080.tres",
	"res://data/levels/level_081.tres",
	"res://data/levels/level_082.tres",
	"res://data/levels/level_083.tres",
	"res://data/levels/level_084.tres",
	"res://data/levels/level_085.tres",
	"res://data/levels/level_086.tres",
	"res://data/levels/level_087.tres",
	"res://data/levels/level_088.tres",
	"res://data/levels/level_089.tres",
	"res://data/levels/level_090.tres",
	"res://data/levels/level_091.tres",
	"res://data/levels/level_092.tres",
	"res://data/levels/level_093.tres",
	"res://data/levels/level_094.tres",
	"res://data/levels/level_095.tres",
	"res://data/levels/level_096.tres",
	"res://data/levels/level_097.tres",
	"res://data/levels/level_098.tres",
	"res://data/levels/level_099.tres",
	"res://data/levels/level_100.tres",
]

## Task-based level groups, used to render a non-clickable header row above
## each group's topmost button in the (bottom-up) list -- see
## _build_level_buttons(). first/last are 1-based level numbers, inclusive.
const GROUPS: Array[Dictionary] = [
	{"name": "Riverbed Basics", "first": 1, "last": 12},
	{"name": "Long Corridors", "first": 13, "last": 17},
	{"name": "Special Waters", "first": 18, "last": 20},
	{"name": "Dig the River", "first": 21, "last": 22},
	{"name": "Diverter Drills", "first": 23, "last": 30},
	{"name": "Wall Work", "first": 31, "last": 38},
	{"name": "Split Networks", "first": 39, "last": 46},
	{"name": "Town Defense", "first": 47, "last": 54},
	{"name": "Flat Fields", "first": 55, "last": 62},
	{"name": "Geyser Country", "first": 63, "last": 70},
	{"name": "Big Digs", "first": 71, "last": 78},
	{"name": "Jamboree Runs", "first": 79, "last": 86},
	{"name": "The Gauntlet", "first": 87, "last": 100},
]

const TOTAL_LEVEL_SLOTS := 100

## Level buttons fill one full-width row each (a vertical list inside a
## ScrollContainer). Height fixed; width stretches via SIZE_EXPAND_FILL.
const BUTTON_HEIGHT := 64.0
const HEADER_HEIGHT := 40.0

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var list: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var back_button: Button = $BackButton
@onready var debug_unlock_toggle: CheckButton = $DebugUnlockToggle


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	debug_unlock_toggle.button_pressed = GameState.debug_unlock_all
	debug_unlock_toggle.toggled.connect(_on_debug_unlock_toggled)
	_build_level_buttons()


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


func _on_debug_unlock_toggled(pressed: bool) -> void:
	GameState.debug_unlock_all = pressed
	_build_level_buttons()


## Builds the list bottom-to-top: level 1 is the LAST child added (bottom of
## the list); level 100 the FIRST (top). A group's header label is added just
## BEFORE its highest-numbered level's button, so on screen it sits directly
## above that group. Combined with _scroll_to_bottom() the screen opens on
## Level 1 and the player scrolls UP through the groups.
func _build_level_buttons() -> void:
	for child in list.get_children():
		child.queue_free()

	for i in range(TOTAL_LEVEL_SLOTS - 1, -1, -1):
		var level_number := i + 1
		for group in GROUPS:
			if level_number == group["last"]:
				list.add_child(_build_group_header(group["name"]))
		if i < LEVEL_PATHS.size():
			list.add_child(_build_level_button(LEVEL_PATHS[i]))
		else:
			list.add_child(_build_placeholder_button(level_number))

	_scroll_to_bottom()


## A non-interactive header row naming the task group below it.
func _build_group_header(group_name: String) -> Label:
	var label := Label.new()
	label.text = "- %s -" % group_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_level_button(path: String) -> Button:
	var level_data: LevelData = load(path)
	var button := Button.new()
	button.text = level_data.display_name
	if GameState.completed_levels.has(level_data.level_id):
		button.text += " *"
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not GameState.is_level_unlocked(level_data.level_id)
	button.pressed.connect(_on_level_selected.bind(path))
	return button


## Kept for safety if LEVEL_PATHS ever shrinks below TOTAL_LEVEL_SLOTS --
## with all 100 levels authored this is normally never built.
func _build_placeholder_button(level_number: int) -> Button:
	var button := Button.new()
	button.text = "%d. Coming soon" % level_number
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = true
	return button


## Starts the view scrolled to the bottom (Level 1). One frame of delay so
## ScrollContainer knows the freshly-built content height; the huge value is
## clamped to the true max automatically.
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = 1000000000


func _on_level_selected(path: String) -> void:
	GameState.pending_level_path = path
	get_tree().change_scene_to_file("res://scenes/Level.tscn")
