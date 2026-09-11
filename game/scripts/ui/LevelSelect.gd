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

## The tutorial track, played before level 1. These sit at the BOTTOM of the
## trail, below level 1, and are always unlocked.
##
## They are deliberately not levels 1-5: numbering them into the campaign
## would have renumbered all 100 authored levels and invalidated every save,
## every entry in level-solutions.md and every doc that names a level by
## number. They carry ids 901-905 instead -- see GameState.TUTORIAL_ID_FIRST.
const TUTORIAL_PATHS: Array[String] = [
	"res://data/levels/tutorial_1.tres",
	"res://data/levels/tutorial_2.tres",
	"res://data/levels/tutorial_3.tres",
	"res://data/levels/tutorial_4.tres",
	"res://data/levels/tutorial_5.tres",
]

## Chapter name over the tutorial stretch of the trail.
const TUTORIAL_GROUP_NAME := "Learning the River"

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

## Every node on the trail, tutorial first: slot 0..4 are the tutorial,
## slot 5.. are levels 1..100. Nothing else in the file may assume that a
## slot index and a level number are the same thing -- they stopped being
## the same when the tutorial was added.
static func total_slots() -> int:
	return TUTORIAL_PATHS.size() + TOTAL_LEVEL_SLOTS


## The trail slot a campaign level number occupies.
static func slot_of_level(level_number: int) -> int:
	return TUTORIAL_PATHS.size() + level_number - 1


## The campaign level number at a trail slot, or 0 for a tutorial slot.
static func level_of_slot(slot: int) -> int:
	var n := slot - TUTORIAL_PATHS.size() + 1
	return n if n >= 1 else 0


## Every playable path in play order -- the tutorial, then the campaign.
## Level.gd's "next level" walks this, so tutorial 5 leads into level 1.
static func campaign_paths() -> Array[String]:
	var paths: Array[String] = []
	paths.append_array(TUTORIAL_PATHS)
	paths.append_array(LEVEL_PATHS)
	return paths

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
## The design width the trail was laid out against. Under
## stretch/aspect=expand the logical viewport is at least this wide and can
## be wider (a 4:3 tablet, an unfolded foldable), so the live width is read
## per build into _map_width and the trail spread across it -- pinning the
## map at 720 would strand it against the left edge of a wider screen with
## dead grass down the right.
const MAP_DESIGN_WIDTH := 720.0
## Clear space above the topmost node, and it has to clear the HeaderBar --
## which is screen chrome drawn over the ScrollContainer, not part of the
## scrolling content, so the map has to leave room for it rather than being
## pushed down by it. At 120 the top node's own edge (centre - NODE_SIZE/2 =
## 120 - 38 = 82) sat behind an 88-tall bar, and its completion badge, which
## overhangs the node by BADGE_SIZE * 0.34 ~= 11, was clipped to a half-disc.
## 88 (bar) + 38 (node half) + 11 (badge overhang) = 137, plus breathing room.
## Note the safe-area inset is added on top of this separately, so a notch
## does not eat into it.
const MAP_MARGIN_TOP := 148.0
const MAP_MARGIN_BOTTOM := 110.0
const HEADER_HEIGHT := 40.0 # height of a chapter-name marker

## Side paths. Every set of ten levels forks at its 8th -- 8, 18, 28 ... 98
## -- into a spur holding a bonus level. Those levels are not authored yet,
## so each spur ends in a placeholder node that cannot be entered; what is
## live today is the gate.
##
## The gate is performance, not progress: the fork opens only once the
## player has finished the fork level inside its par (LevelData.par_measures,
## recorded by GameState.mark_par()). Reaching level 8 is not enough --
## playing it well is. A locked spur is still drawn, faintly, so the player
## can see there is something there to earn.
const BONUS_FORK_OFFSET := 8   # the 8th level of each set of ten
const BONUS_FORK_STEP := 10
const BONUS_SPUR_LENGTH := 152.0
const BONUS_EDGE_MARGIN := 54.0 # keep a spur node clear of the screen edge
const COLOR_BONUS_OPEN := Color(0.93, 0.66, 0.16)
const COLOR_BONUS_LOCKED := Color(0.42, 0.46, 0.5, 0.85)

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

## The width the current map was built for: the safe area's, never less than
## MAP_DESIGN_WIDTH. Set by _build_map(); read by everything that places a
## node, a spur or a chapter label.
var _map_width: float = MAP_DESIGN_WIDTH

## Where that width starts -- the left safe-area inset, 0 on a screen with
## no cutout down its side. Node x coordinates are measured from here.
var _map_left: float = 0.0

## Each header control's offsets as authored in LevelSelect.tscn, captured
## before any inset is applied so _apply_safe_area() can re-derive rather
## than accumulate. Control -> Vector4(left, top, right, bottom).
var _base_offsets: Dictionary = {}

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var map_root: LevelMap = $ScrollContainer/MapRoot
@onready var back_button: Button = $BackButton
@onready var debug_unlock_toggle: CheckButton = $DebugUnlockToggle
@onready var header_bar: ColorRect = $HeaderBar
@onready var header_shadow: ColorRect = $HeaderShadow


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	# Editor and debug exports only. In a release build this is the only
	# control on the screen with words on it -- every other one is a bare
	# icon -- so it reads as a feature and invites the tap. Its own doc
	# comment on GameState.debug_unlock_all calls the flag session-only and
	# therefore harmless, but that is only true of the FLAG: any level played
	# while it is on writes real progress through mark_level_complete(), so
	# one curious tap permanently skips the campaign it was meant not to
	# touch. Hidden rather than deleted -- it stays available in the editor,
	# where testing level 90 without playing 89 levels is the whole point.
	# An invisible Control receives no input, so hiding it is the whole gate.
	debug_unlock_toggle.visible = OS.is_debug_build()
	debug_unlock_toggle.button_pressed = GameState.debug_unlock_all
	debug_unlock_toggle.toggled.connect(_on_debug_unlock_toggled)
	# The viewport is not a constant under stretch/aspect=expand -- it takes
	# the device's aspect, and a desktop window resize can change it again.
	# The trail is laid out in absolute coordinates, so it has to be rebuilt
	# against the new width rather than stretched.
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)
	for control in [back_button, debug_unlock_toggle, header_bar, header_shadow]:
		_base_offsets[control] = Vector4(
			control.offset_left, control.offset_top,
			control.offset_right, control.offset_bottom)
	_apply_safe_area()
	_build_map()


func _on_viewport_resized() -> void:
	_apply_safe_area()
	_build_map()


## Keeps the header row clear of a notch or a cutout. The header BAR itself
## is not moved, only grown: it is the background behind those buttons, and
## a status bar sitting on plain sky reads better than one sitting on a
## dark band. The map's own margins are handled in _build_map().
func _apply_safe_area() -> void:
	var inset := SafeArea.insets(get_viewport())
	_shift_control(back_button, inset.x, inset.y)
	_shift_control(debug_unlock_toggle, -inset.z, inset.y)
	var header_base: Vector4 = _base_offsets[header_bar]
	header_bar.offset_bottom = header_base.w + inset.y
	_shift_control(header_shadow, 0.0, inset.y)


## Moves a control by (dx, dy) from its authored position, whichever edges
## it is anchored to -- all four offsets shift together, so an
## anchored-right control keeps its width.
func _shift_control(control: Control, dx: float, dy: float) -> void:
	var base: Vector4 = _base_offsets[control]
	control.offset_left = base.x + dx
	control.offset_top = base.y + dy
	control.offset_right = base.z + dx
	control.offset_bottom = base.w + dy


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
	_build_map()


## Lays every level out along the trail, adds its node, and hands the trail
## points to LevelMap so it can draw the path underneath them. Rebuilt from
## scratch whenever progress or the debug unlock changes, same as the old
## list was.
func _build_map() -> void:
	# Laid out inside the safe area, so the trail is never partly under a
	# cutout and level 1 never sits behind the gesture bar. Every inset is
	# zero on a screen without one.
	var inset := SafeArea.insets(get_viewport())
	_map_left = inset.x
	_map_width = maxf(MAP_DESIGN_WIDTH, get_viewport_rect().size.x - inset.x - inset.z)
	for child in map_root.get_children():
		map_root.remove_child(child)
		child.queue_free()

	# Walk the campaign once to work out how tall the map is, inserting a
	# gap wherever a new chapter starts, then a second time to place things
	# -- the first pass is what makes the bottom-anchored y values possible.
	var offsets: Array[float] = []
	var label_offsets: Array[Dictionary] = [] # {name, offset up from the bottom}
	var up: float = MAP_MARGIN_BOTTOM + inset.w
	for i in range(total_slots()):
		var level_number := level_of_slot(i)
		var chapter := ""
		if i == 0:
			chapter = TUTORIAL_GROUP_NAME
		elif level_number > 0:
			var group_index := _group_index_starting_at(level_number)
			if group_index != -1:
				chapter = GROUPS[group_index]["name"]
		if chapter != "" and i > 0:
			up += GROUP_GAP
			label_offsets.append({"name": chapter, "offset": up - GROUP_GAP * 0.5})
		elif chapter != "":
			label_offsets.append({"name": chapter,
				"offset": up - (MAP_MARGIN_BOTTOM + inset.w) * 0.55})
		offsets.append(up)
		up += NODE_SPACING
	var content_height: float = up - NODE_SPACING + MAP_MARGIN_TOP + inset.y
	map_root.custom_minimum_size = Vector2(_map_left + _map_width + inset.z, content_height)

	# The wave widens with the screen, so a wider-than-design viewport gets a
	# bigger swing rather than the same narrow trail with dead grass either
	# side of it. At the design width the multiplier is 1 and the layout is
	# unchanged.
	var amplitude: float = NODE_AMPLITUDE * (_map_width / MAP_DESIGN_WIDTH)
	var points := PackedVector2Array()
	for i in range(total_slots()):
		points.append(Vector2(
			_map_left + _map_width * 0.5 + amplitude * sin(i * NODE_PHASE),
			content_height - offsets[i]))

	for entry in label_offsets:
		map_root.add_child(_build_group_label(
			entry["name"], content_height - entry["offset"]))

	# Where the view opens. A brand-new save should land on the tutorial
	# rather than on level 1 -- which is unlocked from the very first launch
	# and would otherwise always win this.
	#
	# Only on a brand-new save, though: gated on the campaign not having
	# started, or a player who skipped the tutorial and is on level 82 gets
	# thrown back to the bottom of the trail every time they open the map,
	# because their tutorial nodes are still unfinished.
	var reached := 1
	var open_at := -1
	var campaign_started: bool = GameState.highest_unlocked_level > 1
	for i in range(total_slots()):
		var level_number := level_of_slot(i)
		if level_number == 0:
			var tutorial_data: LevelData = load(TUTORIAL_PATHS[i])
			reached = maxi(reached, i + 1)
			if (open_at == -1 and not campaign_started
					and not GameState.completed_levels.has(tutorial_data.level_id)):
				open_at = i + 1
			map_root.add_child(_build_level_node(
				tutorial_data, TUTORIAL_PATHS[i], points[i], "T%d" % (i + 1)))
		elif level_number <= LEVEL_PATHS.size():
			var level_data: LevelData = load(LEVEL_PATHS[level_number - 1])
			if GameState.is_level_unlocked(level_data.level_id):
				reached = maxi(reached, i + 1)
			map_root.add_child(_build_level_node(
				level_data, LEVEL_PATHS[level_number - 1], points[i]))
		else:
			map_root.add_child(_build_placeholder_node(level_number, points[i]))

	# Side paths off every 8th level of a set of ten. Indexed by trail SLOT,
	# not by level number -- the tutorial shifted the two apart.
	var spurs: Array[Dictionary] = []
	for gate in range(BONUS_FORK_OFFSET, TOTAL_LEVEL_SLOTS + 1, BONUS_FORK_STEP):
		var anchor: Vector2 = points[slot_of_level(gate)]
		var spur_end := _spur_end(anchor)
		var open: bool = GameState.has_par(gate) or GameState.debug_unlock_all
		spurs.append({"from": anchor, "to": spur_end, "open": open})
		map_root.add_child(_build_bonus_node(gate, spur_end, open))

	map_root.points = points
	map_root.spurs = spurs
	map_root.reached_count = reached
	map_root.queue_redraw()

	# Where the view opens, in order of preference: the level the player
	# just left, if any; else the tutorial on a brand-new save; else their
	# furthest progress. The first is what makes Back from level 24 land on
	# level 24 rather than on level 82.
	var target_slot: int = reached
	if open_at != -1:
		target_slot = open_at
	var last_slot := campaign_paths().find(GameState.last_played_level_path)
	if last_slot != -1:
		target_slot = last_slot + 1
	_scroll_to_reached(points[target_slot - 1].y)


## Where a fork level's spur reaches to. Pushed toward whichever side of the
## map has more room, so a spur never runs off the edge on the outward swing
## of the trail's wave.
func _spur_end(anchor: Vector2) -> Vector2:
	var room_left: float = anchor.x - _map_left - BONUS_EDGE_MARGIN
	var room_right: float = _map_left + _map_width - BONUS_EDGE_MARGIN - anchor.x
	var direction: float = 1.0 if room_right > room_left else -1.0
	var reach: float = minf(BONUS_SPUR_LENGTH, maxf(room_left, room_right))
	return Vector2(anchor.x + direction * reach, anchor.y)


## The node at the end of a side path. Always disabled: these levels do not
## exist yet, so the node advertises the side path rather than entering it.
## Amber once its gate is met, grey and padlocked until then.
func _build_bonus_node(gate_level: int, center: Vector2, open: bool) -> Button:
	var button := Button.new()
	button.name = "bonus_%d" % gate_level
	button.text = "?"
	button.disabled = true
	button.tooltip_text = ("Bonus level — not built yet" if open
		else "Bonus level — finish level %d inside par to open the way" % gate_level)
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.position = center - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	_style_node(button, COLOR_BONUS_OPEN if open else COLOR_BONUS_LOCKED)
	if not open:
		_add_badge(button, ICON_LOCK,
			Vector2(NODE_SIZE - BADGE_SIZE * 0.66, -BADGE_SIZE * 0.34),
			BADGE_BG_LOCK, Color.WHITE)
	return button


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
	label.position = Vector2(_map_left, y - HEADER_HEIGHT * 0.5)
	label.size = Vector2(_map_width, HEADER_HEIGHT)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.14, 0.3, 0.13, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


## One round level node centred on `center`, carrying its number plus
## whichever badges apply: a check once completed, a padlock while locked,
## and -- only on the levels that have a Hydro Plant -- a turbine showing
## whether that level's optional bonus has been earned.
## `label` overrides the text on the node. The campaign uses the level id,
## which IS its number; the tutorial cannot, since its ids are 901-905.
func _build_level_node(level_data: LevelData, path: String, center: Vector2,
		label: String = "") -> Button:
	var unlocked := GameState.is_level_unlocked(level_data.level_id)
	var completed: bool = GameState.completed_levels.has(level_data.level_id)

	var button := Button.new()
	button.name = "level_%d" % level_data.level_id
	button.text = label if label != "" else str(level_data.level_id)
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
	button.name = "level_%d" % level_number
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


## Opens the view on the level the player is actually up to, centred.
##
## This used to slam the scroll to the bottom -- Level 1 -- every single time
## the screen was built, which is on every cold start, every return from a
## level, and every Back out of one. The trail runs bottom-to-top over 100
## nodes, so a player on level 47 landed two and a half screen-heights below
## their own progress and had to drag up to it, every time.
##
## Level 1 still lands at the bottom on a fresh save: `reached` is 1 there, and
## points[0] is the bottom-most node, so the clamp below produces the old
## behaviour exactly. Nothing changes for a new player.
##
## One frame of delay so ScrollContainer knows the freshly-built content
## height; scroll_vertical clamps itself to the real range, so overshooting at
## either end is safe.
func _scroll_to_reached(node_y: float) -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(node_y - scroll.size.y * 0.5)


func _on_level_selected(path: String) -> void:
	GameState.pending_level_path = path
	get_tree().change_scene_to_file("res://scenes/Level.tscn")
