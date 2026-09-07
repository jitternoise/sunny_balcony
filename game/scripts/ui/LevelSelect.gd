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

## Map geometry. Levels are laid out bottom-to-top along a sine-wave trail:
## level 1 sits at the bottom (where the view opens) and the campaign winds
## upward, matching the old list's ordering. The wave is what makes the
## screen read as a journey rather than a column -- NODE_PHASE controls how
## many levels make up one full left-right swing.
const NODE_SIZE := 76.0
const NODE_SPACING := 104.0 # vertical gap between consecutive levels
const GROUP_GAP := 84.0 # extra room inserted where a new chapter begins
const NODE_AMPLITUDE := 200.0 # how far the trail swings either side of centre
const NODE_PHASE := PI / 3.0
const MAP_WIDTH := 720.0 # the project's fixed portrait width
const MAP_MARGIN_TOP := 120.0
const MAP_MARGIN_BOTTOM := 110.0
const HEADER_HEIGHT := 40.0 # height of a chapter-name marker

## Corner badges on a level node. Kept small enough to read as annotations
## on the number rather than competing with it.
const BADGE_SIZE := 32.0
const ICON_CHECK := preload("res://assets/icons/ui_check.svg")
const ICON_LOCK := preload("res://assets/icons/ui_lock.svg")
const ICON_HYDRO := preload("res://assets/icons/ui_hydro.svg")

## Badge backing colours. Each badge sits in its own filled disc so it
## reads against a node of any colour AND against the grass it overhangs --
## the board's own hydro icon was unreadable at this size on a green node,
## which is why the badge uses a white-glyph variant instead.
const BADGE_BG_CHECK := Color(0.13, 0.4, 0.18)
const BADGE_BG_LOCK := Color(0.28, 0.31, 0.34)
const BADGE_BG_BONUS_EARNED := Color(0.93, 0.66, 0.16)
const BADGE_BG_BONUS_MISSING := Color(0.3, 0.47, 0.6)

const COLOR_COMPLETED := Color(0.22, 0.62, 0.31)
const COLOR_UNLOCKED := Color(0.2, 0.55, 0.85)
const COLOR_LOCKED := Color(0.42, 0.46, 0.5, 0.85)

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var map_root: LevelMap = $ScrollContainer/MapRoot
@onready var back_button: Button = $BackButton
@onready var debug_unlock_toggle: CheckButton = $DebugUnlockToggle


func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	debug_unlock_toggle.button_pressed = GameState.debug_unlock_all
	debug_unlock_toggle.toggled.connect(_on_debug_unlock_toggled)
	_build_map()


func _on_debug_unlock_toggled(pressed: bool) -> void:
	GameState.debug_unlock_all = pressed
	_build_map()


## Lays every level out along the trail, adds its node, and hands the trail
## points to LevelMap so it can draw the path underneath them. Rebuilt from
## scratch whenever progress or the debug unlock changes, same as the old
## list was.
func _build_map() -> void:
	for child in map_root.get_children():
		map_root.remove_child(child)
		child.queue_free()

	# Walk the campaign once to work out how tall the map is, inserting a
	# gap wherever a new chapter starts, then a second time to place things
	# -- the first pass is what makes the bottom-anchored y values possible.
	var offsets: Array[float] = []
	var group_label_offsets := {} # group index -> distance up from the bottom
	var up := MAP_MARGIN_BOTTOM
	for i in range(TOTAL_LEVEL_SLOTS):
		var level_number := i + 1
		var group_index := _group_index_starting_at(level_number)
		if group_index != -1 and i > 0:
			up += GROUP_GAP
			group_label_offsets[group_index] = up - GROUP_GAP * 0.5
		elif group_index != -1:
			group_label_offsets[group_index] = up - MAP_MARGIN_BOTTOM * 0.55
		offsets.append(up)
		up += NODE_SPACING
	var content_height: float = up - NODE_SPACING + MAP_MARGIN_TOP
	map_root.custom_minimum_size = Vector2(MAP_WIDTH, content_height)

	var points := PackedVector2Array()
	for i in range(TOTAL_LEVEL_SLOTS):
		points.append(Vector2(
			MAP_WIDTH * 0.5 + NODE_AMPLITUDE * sin(i * NODE_PHASE),
			content_height - offsets[i]))

	for group_index in group_label_offsets.keys():
		map_root.add_child(_build_group_label(
			GROUPS[group_index]["name"], content_height - group_label_offsets[group_index]))

	var reached := 1
	for i in range(TOTAL_LEVEL_SLOTS):
		var level_number := i + 1
		if i < LEVEL_PATHS.size():
			var level_data: LevelData = load(LEVEL_PATHS[i])
			if GameState.is_level_unlocked(level_data.level_id):
				reached = maxi(reached, level_number)
			map_root.add_child(_build_level_node(level_data, LEVEL_PATHS[i], points[i]))
		else:
			map_root.add_child(_build_placeholder_node(level_number, points[i]))

	map_root.points = points
	map_root.reached_count = reached
	map_root.queue_redraw()
	_scroll_to_bottom()


## The index into GROUPS of the chapter that starts at `level_number`, or
## -1 if no chapter starts there.
func _group_index_starting_at(level_number: int) -> int:
	for i in range(GROUPS.size()):
		if GROUPS[i]["first"] == level_number:
			return i
	return -1


## A chapter name, spanning the full width so it reads as a region marker
## the trail passes through rather than a label attached to one level.
func _build_group_label(group_name: String, y: float) -> Label:
	var label := Label.new()
	label.text = "- %s -" % group_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, y - HEADER_HEIGHT * 0.5)
	label.size = Vector2(MAP_WIDTH, HEADER_HEIGHT)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.14, 0.3, 0.13, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


## One round level node centred on `center`, carrying its number plus
## whichever badges apply: a check once completed, a padlock while locked,
## and -- only on the levels that have a Hydro Plant -- a turbine showing
## whether that level's optional bonus has been earned.
func _build_level_node(level_data: LevelData, path: String, center: Vector2) -> Button:
	var unlocked := GameState.is_level_unlocked(level_data.level_id)
	var completed: bool = GameState.completed_levels.has(level_data.level_id)

	var button := Button.new()
	button.text = str(level_data.level_id)
	button.tooltip_text = level_data.display_name
	button.disabled = not unlocked
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.position = center - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	_style_node(button, COLOR_COMPLETED if completed else (COLOR_UNLOCKED if unlocked else COLOR_LOCKED))
	if unlocked:
		button.pressed.connect(_on_level_selected.bind(path))

	var top_right := Vector2(NODE_SIZE - BADGE_SIZE * 0.66, -BADGE_SIZE * 0.34)
	if completed:
		_add_badge(button, ICON_CHECK, top_right, BADGE_BG_CHECK, Color.WHITE)
	elif not unlocked:
		_add_badge(button, ICON_LOCK, top_right, BADGE_BG_LOCK, Color.WHITE)

	# Only the handful of levels that ship a plant advertise the bonus: an
	# amber turbine once it has been earned, a muted one until then, so the
	# levels that still have something to give stand out on the map.
	if not level_data.hydro_plant_cells.is_empty():
		var earned := GameState.has_hydro_bonus(level_data.level_id)
		_add_badge(button, ICON_HYDRO,
			Vector2(-BADGE_SIZE * 0.34, NODE_SIZE - BADGE_SIZE * 0.66),
			BADGE_BG_BONUS_EARNED if earned else BADGE_BG_BONUS_MISSING,
			Color.WHITE)

	return button


## Kept for safety if LEVEL_PATHS ever shrinks below TOTAL_LEVEL_SLOTS --
## with all 100 levels authored this is normally never built.
func _build_placeholder_node(level_number: int, center: Vector2) -> Button:
	var button := Button.new()
	button.text = str(level_number)
	button.tooltip_text = "Coming soon"
	button.disabled = true
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.position = center - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	_style_node(button, COLOR_LOCKED)
	return button


## Repaints one node in `color` and pulls its padding in, so the shared
## theme's text-sized pill becomes a circle at NODE_SIZE.
func _style_node(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		if state == "hover":
			box.bg_color = color.lightened(0.12)
		elif state == "pressed":
			box.bg_color = color.darkened(0.18)
		box.set_corner_radius_all(999)
		box.set_content_margin_all(4.0)
		box.border_color = Color(0, 0, 0, 0.25)
		box.set_border_width_all(3)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_font_size_override("font_size", 22)


## A round badge pinned to one corner of a level node: a filled disc with
## the glyph centred inside it. Both the disc and the glyph ignore mouse
## input so they never eat a tap meant for the node itself.
func _add_badge(button: Button, texture: Texture2D, offset: Vector2,
		background: Color, tint: Color) -> void:
	var disc := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(999)
	box.border_color = Color(1, 1, 1, 0.9)
	box.set_border_width_all(2)
	disc.add_theme_stylebox_override("panel", box)
	disc.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	disc.position = offset
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(disc)

	var glyph := TextureRect.new()
	glyph.texture = texture
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.size = Vector2(BADGE_SIZE, BADGE_SIZE) * 0.68
	glyph.position = Vector2(BADGE_SIZE, BADGE_SIZE) * 0.16
	glyph.modulate = tint
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(glyph)


## Starts the view scrolled to the bottom (Level 1). One frame of delay so
## ScrollContainer knows the freshly-built content height; the huge value is
## clamped to the true max automatically.
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = 1000000000


func _on_level_selected(path: String) -> void:
	GameState.pending_level_path = path
	get_tree().change_scene_to_file("res://scenes/Level.tscn")
