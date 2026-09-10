extends Node2D

## Wires HexBoard's simulation to the tick timer, the inventory/placement
## UI, and win/lose handling + saving. Reads GameState.pending_level_path
## (set by LevelSelect.gd) to know which level to load.

## Beat-cycle timing (see claude/toolset-and-requirements.md's "Music-driven
## timing spec" and claude/dev-progress.md). The engine clock itself never
## changes -- SUBTICK_INTERVAL fires at a constant rate. What changes is how
## many of those constant sub-ticks make up one beat (ticks_per_beat) and,
## within a beat, which phase of the 4-beat measure is active:
##   Beat 1 -- PLACEMENT: queued block placements/removals are committed.
##   Beat 2 -- WATER: water advances one hex (the core simulation step).
##   Beat 3 -- TERRAIN: fire/pool/geyser contact effects from beat 2 resolve.
##   Beat 4 -- STATUS: win/loss is checked and the board's redraw (status
##             bars, extinguished fires, etc.) is revealed.
## Splitting terrain resolution (beat 3) from its visual reveal (beat 4) is
## deliberate: HexBoard.resolve_terrain_phase() mutates state without
## redrawing, and HexBoard.resolve_status_phase() is what actually calls
## queue_redraw() -- so a pool's status-bar box flipping, or a fire going
## out, visibly lands on beat 4 specifically, not silently mid-measure.
const SUBTICK_INTERVAL := 0.15 # seconds per constant engine tick; tune for feel

## How many constant SUBTICK_INTERVAL ticks make up one beat. This is the
## knob that changes tempo -- fewer ticks per beat means a faster beat --
## without ever touching SUBTICK_INTERVAL itself. Was 4 (0.6s/beat,
## matching the old flat-tick pacing); halved to 2 (0.3s/beat) per
## feedback that the game felt slow. A future per-level or dynamic
## (mid-level tempo shift) value would just reassign this at runtime
## instead.
var ticks_per_beat: int = 2

enum BeatPhase { PLACEMENT = 1, WATER = 2, TERRAIN = 3, STATUS = 4 }
var current_beat: int = BeatPhase.PLACEMENT
var _subtick_count: int = 0

## Measures completed since Start. Compared against LevelData.par_measures
## on a win to decide whether this level's par was met -- see
## _on_level_won(). Counted, not derived from the clock, so it cannot drift
## with frame rate or a mid-level pause.
var measures_elapsed: int = 0

@onready var board: HexBoard = $Board

## The Control every HUD element is anchored inside. Inset by _apply_safe_area().
@onready var hud: Control = $UI/HUD
@onready var status_label: Label = $UI/HUD/StatusLabel
@onready var budget_label: Label = $UI/HUD/BudgetLabel
@onready var inventory_bar: HBoxContainer = $UI/HUD/InventoryBar
@onready var back_button: Button = $UI/HUD/BackButton
@onready var start_button: Button = $UI/HUD/StartButton
@onready var pause_button: Button = $UI/HUD/PauseButton
@onready var tick_timer: Timer = $TickTimer

## Modal-style popup shown while the game is paused (see _on_pause_pressed()):
## a dimmed overlay that swallows every board tap/drag underneath it, plus a
## centered "Paused" panel with Resume / Retry / Level Select buttons. Unlike
## the lose popup, this one is meant to block the board entirely -- a paused
## game shouldn't let the player keep placing or picking up blocks while the
## water is frozen.
@onready var pause_panel: Control = $UI/PausePanel
@onready var pause_resume_button: Button = $UI/PausePanel/Center/Panel/VBox/ResumeButton
@onready var pause_retry_button: Button = $UI/PausePanel/Center/Panel/VBox/ButtonRow/RetryButton
@onready var pause_level_select_button: Button = $UI/PausePanel/Center/Panel/VBox/ButtonRow/LevelSelectButton

## Small modal-style popup shown on a loss (see _on_level_lost()): a dimmed
## overlay plus a centered panel with the loss reason and two buttons,
## Retry and Level Select. Sits on top of the HUD's Back button, which
## still works too; this panel carries the only Retry available on a loss.
@onready var lose_panel: Control = $UI/LosePanel
@onready var lose_reason_label: Label = $UI/LosePanel/Center/Panel/VBox/ReasonLabel
@onready var lose_retry_button: Button = $UI/LosePanel/Center/Panel/VBox/ButtonRow/RetryButton
@onready var lose_level_select_button: Button = $UI/LosePanel/Center/Panel/VBox/ButtonRow/LevelSelectButton

## Modal-style popup shown the instant a level loads, explaining what it
## does (LevelData.intro_text) before the player can touch anything else.
## Structured identically to lose_panel above (dimmed ColorRect + centered
## PanelContainer) and, like lose_panel, is added as the LAST child under
## UI so it draws on top of -- and is hit-tested before -- every other UI
## node, including the HUD's Start/Pause/Back buttons and the inventory
## bar. Its Dim rect has mouse_filter = MOUSE_FILTER_STOP (1), so while
## intro_panel.visible is true, any tap/click anywhere on screen is
## consumed by that rect and never reaches a button underneath -- this is
## what actually makes "the other buttons don't work until the window
## closes" true, not just a visual overlay.
@onready var intro_panel: Control = $UI/IntroPanel
@onready var intro_title_label: Label = $UI/IntroPanel/Center/Panel/VBox/TitleLabel
@onready var intro_description_label: Label = $UI/IntroPanel/Center/Panel/VBox/DescriptionLabel
@onready var intro_got_it_button: Button = $UI/IntroPanel/Center/Panel/VBox/GotItButton

## Modal-style popup shown on a win (see _on_level_won()): a dimmed overlay
## plus a centered panel reading "Success!" with a single Next button.
## Same structure/blocking mechanism as lose_panel/intro_panel above, and
## is the LAST child under UI (after intro_panel) so it also draws on top
## of and is hit-tested before everything else. Replaces the previous
## behavior of auto-returning to Level Select after a timed delay -- the
## player now explicitly advances via Next instead of the scene changing
## out from under them.
@onready var win_panel: Control = $UI/WinPanel
@onready var win_next_button: Button = $UI/WinPanel/Center/Panel/VBox/NextButton

## Reports the optional Hydro Plant bonus on the win popup (see
## _on_level_won()). Stays hidden on the levels that have no plant, which
## is most of them.
@onready var win_bonus_label: Label = $UI/WinPanel/Center/Panel/VBox/BonusLabel

var level_data: LevelData
var block_catalog: Dictionary = {}
var started: bool = false

## True while the pause popup is up (see _on_pause_pressed()). The tick timer
## is held (tick_timer.paused) rather than stopped, so resuming picks the
## beat cycle back up exactly where it left off, mid-measure and all.
var paused: bool = false

## True while the inventory bar's Delete button is toggled on (see
## _build_inventory_bar() / _on_delete_button_toggled()). In this mode a tap
## on a placed block removes it (refunding it to inventory) and a tap on an
## empty cell does nothing -- no block is ever placed, whatever was selected
## before. Picking a block from the inventory bar switches the mode back off.
var delete_mode: bool = false
const DELETE_BUTTON_NAME := "delete_mode"
const DELETE_ICON := preload("res://assets/icons/ui_trash.svg")

## Win-popup button glyphs -- which one is shown depends on whether another
## level follows this one (see _on_level_won()).
const NEXT_ICON := preload("res://assets/icons/ui_next.svg")
const EXIT_ICON := preload("res://assets/icons/ui_exit.svg")

## Inventory-bar button sizing. The shared theme pads buttons for text
## (28px each side), which leaves an icon-led button almost no room: with
## expand_icon on, Godot reserves no minimum width for the icon, so the
## tile art collapses to nothing inside that padding. These buttons
## therefore get a fixed width and much tighter side padding, so the tile
## image itself is the button and the count sits beside it.
## The tile buttons are wider than the Delete toggle: their tile art is the
## thing being chosen, while Delete is a mode switch with a fixed-size glyph.
const INVENTORY_BUTTON_WIDTH := 100.0
## Was 72, which is 36dp on a 360dp phone -- three quarters of Android's 48dp
## minimum, on the control that erases a placement. Narrower than a tile
## button is still fine visually (its glyph is fixed-size), but not narrower
## than a thumb. Level 19 is the binding case: five tile buttons plus this one
## must fit the bar's 640 units, which VerifyTouchTargets checks.
const DELETE_BUTTON_WIDTH := 96.0
const INVENTORY_BUTTON_PADDING := 10.0

## The res://data/levels/*.tres path this scene was loaded with (captured
## from GameState.pending_level_path at the very start of _ready(), before
## anything else has a chance to overwrite that global). Used by the win
## popup's Next button to look up this level's position in
## LevelSelect.LEVEL_PATHS and figure out what "next" means.
var _level_path: String = ""

## Movement (in px) a press has to travel before it's treated as a scroll
## drag instead of a tap-to-place/remove-block. Keeps a slightly-shaky tap
## from being misread as a scroll, while still letting a real drag scroll
## a grid taller than one screen (see HexBoard.max_scroll_down).
const DRAG_THRESHOLD := 16.0

var _press_pos: Vector2 = Vector2.ZERO
var _press_active: bool = false
var _drag_active: bool = false # true once the current press has moved past DRAG_THRESHOLD

## Pointer id for a mouse, which has no finger index of its own. Negative so
## it can never collide with a real InputEventScreenTouch.index (0, 1, 2...).
const MOUSE_POINTER := -1

## Which pointer owns the press in progress -- a finger index on a
## touchscreen, MOUSE_POINTER on desktop. Only this pointer's drags and its
## release act on the board; every other one is ignored until it lets go.
##
## The board is a single-pointer surface and the state above (_press_pos,
## _drag_active, the whole catapult sequence) only ever described ONE press,
## but nothing enforced that. Phones are multi-touch and a second contact is
## not exotic -- it is the thumb of the hand holding the phone brushing the
## glass, on the 38 levels whose board is taller than the screen and has to
## be scrolled one-handed. Without an owner:
##
##   - a second finger's touch-down overwrote _press_pos mid-gesture, so the
##     scrolling finger's own release then measured its drag from the wrong
##     origin and read as a tap;
##   - worse, the release branch never checked _press_active at all, so ANY
##     unmatched touch-up ran the full tap path and placed or deleted a
##     block at wherever that finger happened to lift;
##   - and a stray contact during the ~700ms motionless hold that charges a
##     Bomb Catapult cancelled the shot, placed a block, and left the aim
##     overlay drawn on the board with nothing aiming it.
var _press_index: int = MOUSE_POINTER

## Bomb Catapult aiming (see HexBoard.fire_catapult()/set_catapult_aim()):
## how long a press has to hold on a live catapult cell before the
## aim/charge sequence begins -- below this, releasing is treated as an
## ordinary tap (pickup, if the catapult is player-placed; a no-op on a
## preset one), exactly like every other block. Keeps a quick, deliberate
## tap from accidentally launching a bomb.
const CATAPULT_HOLD_THRESHOLD_MSEC := 300

## Once charging begins, how long the player has to keep holding for the
## aim to grow by one more tile of range, from HexBoard.CATAPULT_MIN_RANGE
## up to HexBoard.CATAPULT_MIN_RANGE + HexBoard.CATAPULT_MAX_EXTRA_RANGE.
const CATAPULT_CHARGE_MSEC_PER_TILE := 350

## True from the instant a press LANDS on a cell holding a live (unspent)
## Bomb Catapult block, before it's known whether this press will turn
## into a hold-to-aim sequence or an ordinary quick tap -- see
## _unhandled_input()'s is_press branch and _is_live_catapult(). Checked
## every frame by _process() to decide when to promote the press into
## _catapult_aiming.
var _catapult_press_active: bool = false
var _catapult_press_coord: Vector2i = Vector2i.ZERO
var _catapult_press_started_msec: int = 0

## True once a catapult press has been held past CATAPULT_HOLD_THRESHOLD_MSEC
## (set by _process()). While true: normal board-scroll dragging is
## suppressed for this press (see is_drag_motion's branch below) and
## instead every drag/frame recomputes the aimed direction/charged
## distance (see _update_catapult_aim()); releasing fires the shot instead
## of falling through to ordinary tap handling.
var _catapult_aiming: bool = false
var _catapult_charge_started_msec: int = 0
var _catapult_last_drag_pos: Vector2 = Vector2.ZERO
var _catapult_direction: Vector2i = Hex.DOWN_LEFT

## The charged distance from the most recent aim preview frame. Firing uses
## THIS rather than recomputing from the clock at release time, so the shot
## that goes off is exactly the one the player was looking at -- a release
## landing just after a charge tick used to fire one tile further than the
## preview had ever shown.
var _catapult_last_distance: int = HexBoard.CATAPULT_MIN_RANGE

## Double-tap detection for the Hydro Plant (see
## HexBoard.try_activate_hydro()/hydro_ready_at()). A second tap landing on
## the SAME hex within DOUBLE_TAP_WINDOW_MSEC of the first counts as a
## double-tap; anything slower is just two separate ordinary taps.
## Deliberately generous (touchscreens are less precise than a mouse) --
## 400ms is a common double-tap window on mobile OSes.
const DOUBLE_TAP_WINDOW_MSEC := 400
var _last_tap_coord: Vector2i = Vector2i(99999, 99999) # sentinel -- never a real board coord
var _last_tap_msec: int = 0


func _ready() -> void:
	block_catalog = _load_block_catalog()
	_level_path = GameState.pending_level_path
	level_data = load(_level_path)

	board.setup(level_data, block_catalog)
	board.level_won.connect(_on_level_won)
	board.level_lost.connect(_on_level_lost)

	tick_timer.wait_time = SUBTICK_INTERVAL
	tick_timer.timeout.connect(_on_subtick)
	# Deliberately NOT started here -- the player gets unlimited time to
	# place blocks first and presses Start when ready. Once ticking begins,
	# blocks can still be placed AND removed in real time -- Start just
	# controls whether water is actively flowing, not whether the board can
	# be edited. A placement/removal made mid-measure is queued by
	# HexBoard.place_block()/remove_block() and only takes effect on the
	# next PLACEMENT beat -- see the beat-cycle doc comment above.

	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_apply_safe_area):
		vp.size_changed.connect(_apply_safe_area)

	back_button.pressed.connect(_go_to_level_select)
	start_button.pressed.connect(_on_start_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	pause_resume_button.pressed.connect(_on_resume_pressed)
	pause_retry_button.pressed.connect(_on_retry_pressed)
	pause_level_select_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))
	lose_retry_button.pressed.connect(_on_retry_pressed)
	lose_level_select_button.pressed.connect(_go_to_level_select)
	intro_got_it_button.pressed.connect(_on_intro_got_it_pressed)
	win_next_button.pressed.connect(_on_win_next_pressed)

	_build_inventory_bar()
	_set_pre_start_status()
	_apply_safe_area()
	_show_intro_popup_if_needed()


## Keeps the HUD clear of notches, cutouts and the gesture bar. The board
## insets itself (HexBoard._fit_hex_layout()); this is the other half, and
## it is one call because every HUD control is anchored inside $UI/HUD.
## The backgrounds are NOT inset: Sky and Grass live on their own
## CanvasLayer and stay full-bleed, so the inset shows up as the HUD
## sitting further in, never as a dark band down the edge of the screen.
##
## Re-applied on viewport resize for the same reason the board re-fits: the
## viewport is not a constant under stretch/aspect=expand, and a device
## reports its safe area against the current one.
func _apply_safe_area() -> void:
	SafeArea.inset_full_rect(hud, SafeArea.insets(get_viewport()))


## Where both the HUD Back button and the lose popup's "Level Select" button
## go, pulled out of the old inline lambdas so the Android Back handler below
## can reuse it -- all three must always agree.
func _go_to_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")


## Android's hardware/gesture Back. See MainMenu.gd's _notification() for why
## the engine's own quit_on_go_back handling is switched off project-wide.
## Never fires on iOS.
##
## Back is treated as "undo the innermost thing on screen", so it unwinds in
## the same order a player would expect to tap out of: dismiss the intro popup
## first, then abandon an in-progress catapult aim, and only leave the level
## once neither is up. The win/lose popups deliberately fall through to the
## last case -- both already offer Level Select as a button, and Back agreeing
## with that is less surprising than Back dismissing a popup that would leave
## the player staring at a finished board with nothing to do.
## Abandons a charging catapult shot WITHOUT firing it, restoring exactly the
## state a press that never touched a catapult would have left behind. The
## block is not spent -- fire_catapult() is the only thing that consumes one,
## and it is deliberately not called here.
func _cancel_catapult_aim() -> void:
	_catapult_aiming = false
	_catapult_press_active = false
	_press_active = false
	_drag_active = false
	board.clear_catapult_aim()


## Shows the level-intro popup (see intro_panel doc comment above) if this
## level has intro_text set, blocking every other on-screen button until
## the player taps "Got it". A level with an empty intro_text (the field's
## default) skips this entirely -- no popup, nothing blocked, same as
## before this feature existed.
## The pre-Start prompt. Authored in Level.tscn as "Place your blocks, then
## press play", which is wrong on a level that hands out no blocks -- the
## first two tutorials are watch-only, and telling a brand-new player to
## place blocks they do not have is the worst possible first instruction.
func _set_pre_start_status() -> void:
	var has_blocks: bool = (board.use_block_budget
		or not level_data.starting_inventory.is_empty())
	status_label.text = ("Place your blocks, then press play" if has_blocks
		else "Press play and watch")


func _show_intro_popup_if_needed() -> void:
	if level_data.intro_text.is_empty():
		intro_panel.visible = false
		return
	intro_title_label.text = level_data.display_name
	intro_description_label.text = level_data.intro_text
	intro_panel.visible = true


func _on_intro_got_it_pressed() -> void:
	intro_panel.visible = false


## Starts the tick timer. Also immediately hides the pre-start flow-preview
## arrows (board.show_flow_preview -- see HexBoard.gd's doc comment on that
## var) and forces a redraw right here, rather than waiting for the first
## STATUS beat's own queue_redraw() call a measure later -- the preview
## should disappear the instant Start is tapped, not a measure after.
func _on_start_pressed() -> void:
	if started:
		return
	started = true
	start_button.disabled = true
	# From here on, block placements/removals buffer to the next
	# PLACEMENT beat instead of landing immediately -- see HexBoard.started.
	board.started = true
	board.show_flow_preview = false
	board.queue_redraw()
	tick_timer.start()
	_update_status_label()


## Resets the level in place without leaving the scene -- re-runs setup() on
## the board (clearing terrain/water/inventory back to the level's starting
## state), stops the timer, and re-arms the Start button. Available at any
## time, including after a loss or mid-flow, so retrying a level never
## requires a round trip through Level Select. Shared by the pause menu's
## Retry button and the lose-popup's Retry button -- the HUD itself no
## longer carries one. Deliberately does
## NOT re-show the intro popup -- the player has already seen it once this
## visit to the level, and a Retry mid-attempt shouldn't re-block input on
## something they've already acknowledged. board.setup() (called below)
## resets board.show_flow_preview back to true on its own, so the flow
## preview arrows correctly reappear on a Retry. Any dirt cells (the "Dig
## the River" mechanic) are reset back to fully undug by the same setup()
## call -- dig progress is per-attempt, not preserved across retries.
func _on_retry_pressed() -> void:
	lose_panel.visible = false
	win_panel.visible = false
	pause_panel.visible = false
	paused = false
	tick_timer.paused = false
	tick_timer.stop()
	started = false
	pause_button.disabled = false
	delete_mode = false
	current_beat = BeatPhase.PLACEMENT
	_subtick_count = 0
	measures_elapsed = 0
	start_button.disabled = false
	board.selected_block_id = ""
	board.setup(level_data, block_catalog)
	_build_inventory_bar()
	# Retry puts the level back to its pre-Start state, so the prompt should
	# be the pre-Start one -- not a fire count, which is what a level that
	# is actually running shows.
	_set_pre_start_status()


## Freezes the game: holds the tick timer (so no beat advances and the water
## stops mid-flow), cancels any press/aim in progress so a half-charged
## catapult can't fire on resume, and raises the pause popup, whose dimmed
## overlay swallows every board tap until Resume is pressed.
##
## Available before Start as well, where it acts as the in-level menu: since
## the HUD no longer carries its own Retry button, this panel is the only
## route to Retry, and a player who mis-planned their pre-start layout still
## needs a way to reset it. Pausing a game that has not started is harmless
## -- the tick timer is already stopped, so holding it changes nothing, and
## Resume just closes the panel.
func _on_pause_pressed() -> void:
	if paused or board.game_over:
		return
	paused = true
	tick_timer.paused = true
	_press_active = false
	_drag_active = false
	_catapult_press_active = false
	_catapult_aiming = false
	board.clear_catapult_aim()
	pause_button.disabled = true
	pause_panel.visible = true


## Mobile: drop into the pause menu the moment the app leaves the
## foreground, so a player who takes a call, pulls down the notification
## shade or switches apps does not come back to water that kept flowing
## without them.
##
## Three notifications, because no single one covers every way a phone takes
## the foreground away. APPLICATION_PAUSED is the Android/iOS suspend;
## APPLICATION_FOCUS_OUT fires for the things that steal focus without
## suspending; WM_WINDOW_FOCUS_OUT is the desktop equivalent, which is what
## makes this reachable in a test outside a device. They overlap on purpose
## -- pausing an already-paused level is a no-op.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_pause_for_background()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_go_back_request()


## Android's back button/gesture. The project disables Godot's default
## response to it (quitting outright -- see quit_on_go_back in
## project.godot), so every screen has to give it a meaning; here that is
## "the obvious way out of whatever is currently on screen". Never reached
## on iOS, which has no back button: there the home gesture backgrounds the
## app instead, which the notifications above already cover.
func _on_go_back_request() -> void:
	if not is_node_ready() or board == null:
		return
	if intro_panel != null and intro_panel.visible:
		_on_intro_got_it_pressed()           # back dismisses the briefing
	elif _catapult_aiming:
		_cancel_catapult_aim()               # back abandons a charging shot,
		                                     # without spending the block
	elif board.game_over:
		_go_to_level_select()
	elif paused:
		_on_resume_pressed()                 # back closes the menu it opened
	else:
		_on_pause_pressed()


## Opens the pause menu on losing the foreground. Deliberately does nothing
## when another panel already owns the screen: a win or loss has already
## ended the run (board.game_over), and stacking the pause panel on top of
## the level intro would only cost the player an extra tap on the way back
## in. Guarded against firing before _ready(), since these notifications are
## delivered to every node regardless of how far through setup it is.
func _pause_for_background() -> void:
	if not is_node_ready() or paused:
		return
	if board == null or board.game_over:
		return
	if intro_panel != null and intro_panel.visible:
		return
	_on_pause_pressed()


## Unfreezes a paused game -- the tick timer resumes from exactly where it
## was held, so the beat cycle continues on the same sub-tick.
func _on_resume_pressed() -> void:
	if not paused:
		return
	paused = false
	tick_timer.paused = false
	pause_button.disabled = false
	pause_panel.visible = false


## Loads every BlockData .tres under res://data/blocks/ so adding a new
## block type is just "add a .tres file", no script edits.
##
## ResourceLoader.list_directory(), NOT DirAccess. The two disagree the moment
## the game is exported, and only one of them is right. Godot's exporter
## converts text resources to binary by default, which does not leave a .tres
## behind: each one becomes a .tres.remap pointing at a .res inside .godot/.
## A DirAccess scan therefore sees five "wall.tres.remap" entries, an
## ends_with(".tres") test matches none of them, and the catalog comes back
## EMPTY -- every level loads with nothing in the inventory bar and no way to
## place a block. ResourceLoader.list_directory() resolves remaps and returns
## the original .tres names on both sides of an export.
##
## Nothing in tests/ or tools/ can catch a regression here, because they all
## run against the source tree, where the .tres files really are on disk and
## a DirAccess scan works fine. It only shows up in a built PCK.
func _load_block_catalog() -> Dictionary:
	var catalog := {}
	for file_name in ResourceLoader.list_directory("res://data/blocks/"):
		if file_name.ends_with(".tres"):
			var block: BlockData = load("res://data/blocks/" + file_name)
			catalog[block.id] = block
	return catalog


## Builds one button per placeable block type. A normal level offers exactly
## the block ids listed in starting_inventory (its per-type counts, shown by
## _refresh_inventory_labels()). A "jamboree" level (board.use_block_budget)
## instead offers every block id in the full catalog -- the player can place
## any variety, capped only by the shared board.block_budget_remaining pool
## -- so the button list comes from block_catalog.keys() there instead.
func _build_inventory_bar() -> void:
	# remove_child() (not just queue_free()) so the old buttons free up their
	# names immediately -- queue_free() alone defers removal to end of frame,
	# and since the new buttons below reuse the same "block_<id>" names
	# while the old ones are still technically children, Godot silently
	# renames the NEW buttons to avoid the collision. _refresh_inventory_labels()
	# would then label the old (soon-to-be-freed) buttons instead of the new
	# ones, leaving the new buttons blank once the old ones are freed --
	# exactly the "buttons disappear after Retry" bug this fixes.
	for child in inventory_bar.get_children():
		inventory_bar.remove_child(child)
		child.queue_free()

	# What this level actually offers. A level can offer nothing at all --
	# the first two tutorials are watch-only -- and then the whole bar is
	# skipped, delete button included: an eraser with nothing to erase is
	# clutter on the first screen a new player ever sees.
	var block_ids: Array = block_catalog.keys() if board.use_block_budget else level_data.starting_inventory.keys()
	if block_ids.is_empty():
		return

	# Delete (eraser) mode toggle -- the first button in the bar on every
	# level that has something to place, since those all let the player pick
	# blocks back up. See delete_mode / _on_delete_button_toggled().
	var delete_button := Button.new()
	delete_button.name = DELETE_BUTTON_NAME
	delete_button.icon = DELETE_ICON
	delete_button.tooltip_text = "Delete blocks"
	delete_button.toggle_mode = true
	delete_button.button_pressed = delete_mode
	delete_button.toggled.connect(_on_delete_button_toggled)
	inventory_bar.add_child(delete_button)
	_style_inventory_button(delete_button, DELETE_BUTTON_WIDTH)

	for block_id in block_ids:
		var block: BlockData = block_catalog[block_id]
		var button := Button.new()
		button.name = "block_%s" % block_id
		button.icon = block.icon
		button.expand_icon = true # the board SVGs are far larger -- let them shrink to fit
		# The theme caps Button icons at 32px so the 3x-rasterised ui_*.svg
		# glyphs still draw at their authored size (see oval_theme.tres).
		# Tile art is the exception: it IS the button, and expand_icon
		# already sizes it, so lift the cap here.
		button.add_theme_constant_override("icon_max_width", 0)
		button.tooltip_text = block.display_name
		button.pressed.connect(_on_block_button_pressed.bind(block_id))
		inventory_bar.add_child(button)
		_style_inventory_button(button)

	budget_label.visible = board.use_block_budget
	_refresh_inventory_labels()


## Gives one inventory-bar button its fixed width and tightened padding --
## see INVENTORY_BUTTON_WIDTH. Must run AFTER the button is in the tree,
## since get_theme_stylebox() only resolves once the node can see the
## project theme.
func _style_inventory_button(button: Button, width: float = INVENTORY_BUTTON_WIDTH) -> void:
	button.custom_minimum_size = Vector2(width, 0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBox = button.get_theme_stylebox(state)
		if box == null:
			continue
		var tightened: StyleBox = box.duplicate()
		tightened.content_margin_left = INVENTORY_BUTTON_PADDING
		tightened.content_margin_right = INVENTORY_BUTTON_PADDING
		button.add_theme_stylebox_override(state, tightened)


func _refresh_inventory_labels() -> void:
	if board.use_block_budget:
		# One shared pool -- every button just names its block type (no
		# per-type count to show) and all of them disable together the
		# instant the shared pool hits zero, rather than each tracking its
		# own remaining count.
		var out_of_blocks := board.block_budget_remaining <= 0
		for block_id in block_catalog.keys():
			var button := inventory_bar.get_node_or_null("block_%s" % block_id)
			if button:
				# No per-type count in this mode, so the tile art stands
				# alone and BudgetLabel carries the shared pool.
				button.text = ""
				button.disabled = out_of_blocks
		budget_label.text = "Tiles left: %d" % board.block_budget_remaining
		return

	for block_id in board.inventory.keys():
		var button := inventory_bar.get_node_or_null("block_%s" % block_id)
		if button:
			# The tile's own art identifies the block (its name is on the
			# tooltip), so the label is just how many are left.
			button.text = "x%d" % board.inventory[block_id]
			button.disabled = board.inventory[block_id] <= 0


func _on_block_button_pressed(block_id: String) -> void:
	board.selected_block_id = block_id
	_set_delete_mode(false)


## Toggled by the inventory bar's Delete button. Turning it on deselects
## whatever block was selected so the next tap can only ever remove, never
## place; turning it off just returns to the ordinary tap-to-place flow
## with nothing selected.
func _on_delete_button_toggled(toggled_on: bool) -> void:
	delete_mode = toggled_on
	if toggled_on:
		board.selected_block_id = ""


func _set_delete_mode(enabled: bool) -> void:
	delete_mode = enabled
	var delete_button: Button = inventory_bar.get_node_or_null(DELETE_BUTTON_NAME)
	if delete_button and delete_button.button_pressed != enabled:
		delete_button.set_pressed_no_signal(enabled)


func _unhandled_input(event: InputEvent) -> void:
	# Drop the mouse events Godot synthesizes from touch. The project setting
	# input_devices/pointing/emulate_mouse_from_touch is on by default and has
	# to stay on: BaseButton only ever looks at InputEventMouseButton, never
	# InputEventScreenTouch, so every Button in the HUD, the inventory bar and
	# the popups is tapped purely through this emulation. The cost is that on a
	# phone each touch ALSO arrives here as a synthetic mouse event -- and the
	# engine dispatches that copy FIRST, before the real InputEventScreenTouch
	# (Input::_parse_input_event_impl recurses into the emulated event before
	# dispatching the original). Without this guard one finger ran the press
	# and release paths twice: two _handle_tap() calls on the same coord inside
	# DOUBLE_TAP_WINDOW_MSEC read as a deliberate double-tap and activated a
	# Hydro Plant nobody double-tapped, and a place-then-pick-up pair cancelled
	# itself out.
	#
	# Every emulated event, button and motion alike, carries
	# InputEvent.DEVICE_ID_EMULATION (-1) as its device id -- the documented
	# way to tell it from a physical mouse. A real desktop mouse keeps its
	# non-negative device id, so the mouse and wheel paths below are unaffected.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	# A paused game is frozen for input too. The pause popup's dimmed
	# overlay already swallows taps/drags before they get here, but a
	# scroll wheel or a stray release event can still arrive -- ignore
	# everything until Resume.
	if paused:
		return

	# Mouse wheel: a simple scroll shortcut for desktop testing. Grids that
	# fit entirely on screen have max_scroll_down == 0, so this is a no-op
	# for them.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(-40.0)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(40.0)
			return

	var is_press := false
	var is_release := false
	var is_drag_motion := false
	var screen_pos := Vector2.ZERO
	var motion_delta := Vector2.ZERO
	var pointer := MOUSE_POINTER

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		screen_pos = event.position
		if event.pressed:
			is_press = true
		else:
			is_release = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		is_drag_motion = true
		screen_pos = event.position
		motion_delta = event.relative
	elif event is InputEventScreenTouch:
		pointer = event.index
		screen_pos = event.position
		if event.pressed:
			is_press = true
		else:
			is_release = true
	elif event is InputEventScreenDrag:
		pointer = event.index
		is_drag_motion = true
		screen_pos = event.position
		motion_delta = event.relative

	if is_press:
		# First finger down owns the board until it lifts. A second one is
		# dropped here rather than allowed to overwrite the press in
		# progress -- see _press_index.
		if _press_active and pointer != _press_index:
			return
		_press_index = pointer
		_press_pos = screen_pos
		_press_active = true
		_drag_active = false

		# Bomb Catapult: note whether this press landed on a live catapult
		# cell, and start its hold-threshold clock -- _process() promotes
		# this into an aiming sequence if the press is still down once
		# CATAPULT_HOLD_THRESHOLD_MSEC elapses. A press that ISN'T on a
		# catapult just leaves _catapult_press_active false and every
		# catapult-specific branch below/in _process() is a no-op.
		var local_pos: Vector2 = board.to_local(screen_pos)
		var coord := board.screen_to_hex(local_pos)
		_catapult_press_coord = coord
		_catapult_press_active = _is_live_catapult(coord)
		# Belt and braces: a new press can only begin once the last one
		# released, which already ends any aim, so this should never find
		# one live. If it ever does, clear the board's overlay with it --
		# dropping the flag alone would leave an aim drawn on the board
		# that nothing is aiming.
		if _catapult_aiming:
			board.clear_catapult_aim()
		_catapult_aiming = false
		_catapult_press_started_msec = Time.get_ticks_msec()
		return

	if is_drag_motion and _press_active:
		if pointer != _press_index:
			return # a second finger sliding on the glass never scrolls or aims
		if _catapult_aiming:
			# Aiming a catapult shot suppresses ordinary board-scroll
			# dragging for this press entirely -- every drag instead just
			# updates where the player's finger/cursor currently is, which
			# _update_catapult_aim() (called every frame by _process())
			# uses to recompute the aimed direction.
			_catapult_last_drag_pos = screen_pos
			return
		if not _drag_active and screen_pos.distance_to(_press_pos) > DRAG_THRESHOLD:
			# This press is a board scroll, not a hold-to-aim. Drop its
			# catapult candidacy so _process() can't later promote it into
			# an aiming sequence mid-drag -- which is what used to make a
			# scroll that merely STARTED on a catapult fire the shot on
			# release, spending a one-use block the player never aimed.
			# Unconditional: wandering off a catapult abandons the aim
			# whether or not the board can scroll.
			_catapult_press_active = false
			# ...but only call it a scroll if there is something to scroll.
			# On a grid that fits the screen max_scroll_down is 0, so the
			# drag branch below moves nothing and the only thing promoting
			# this press to a drag achieves is to suppress the tap at
			# release. DRAG_THRESHOLD is 16 viewport units, which is ~24
			# device px (~1.4 mm) on a 1080-wide phone -- well inside the
			# roll of an ordinary thumb tap. So on the majority of levels,
			# whose boards fit, a slightly shaky tap silently did nothing
			# at all: no block, no scroll, no feedback, which reads as an
			# unresponsive game rather than a missed input.
			if board.max_scroll_down > 0.0:
				_drag_active = true
		if _drag_active:
			_scroll_by(motion_delta.y)
		return

	if is_release:
		# Only the owning pointer's lift ends the press. This guard is the
		# important half of the multi-touch fix: the branch below runs
		# _handle_tap(), which places or deletes a block, and it used to run
		# for ANY touch-up -- including one from a finger that never pressed
		# the board at all. A thumb resting on the glass and lifting was
		# enough to mutate the board.
		#
		# (A release arriving while the level is paused was already safe:
		# the `if paused: return` above short-circuits first. This is about
		# the unpaused case.)
		if not _press_active or pointer != _press_index:
			return
		var was_drag := _drag_active
		var was_aiming := _catapult_aiming
		_press_active = false
		_drag_active = false
		_catapult_aiming = false
		_catapult_press_active = false

		if was_aiming:
			board.fire_catapult(_catapult_press_coord, _catapult_direction, _catapult_last_distance)
			return

		if was_drag:
			return # this press ended a scroll, not a tap -- don't place/remove
		_handle_tap(screen_pos)


## Promotes a held Bomb Catapult press into an aiming sequence once it's
## been down past CATAPULT_HOLD_THRESHOLD_MSEC, and keeps the aim preview
## updating every frame while charging (the charged distance grows purely
## with hold TIME, so this still needs to run even if the player's
## finger/cursor hasn't moved at all -- see _update_catapult_aim()).
## A no-op every frame for any press that isn't on a catapult.
func _process(_delta: float) -> void:
	_update_board_animation()
	if paused:
		return
	if _catapult_aiming:
		_update_catapult_aim()
		return
	if not _catapult_press_active:
		return
	if _drag_active:
		# Belt and braces with the drag branch in _unhandled_input(): a
		# press that has already turned into a scroll never becomes an aim.
		_catapult_press_active = false
		return
	if Time.get_ticks_msec() - _catapult_press_started_msec < CATAPULT_HOLD_THRESHOLD_MSEC:
		return
	_catapult_aiming = true
	_catapult_charge_started_msec = Time.get_ticks_msec()
	_catapult_last_drag_pos = _press_pos
	_catapult_direction = Hex.DOWN_LEFT # default aim until the player drags away from the catapult
	_update_catapult_aim()


## Stops the board's animation heartbeat whenever the player cannot see the
## board: paused, or with a full-screen panel over it.
##
## HexBoard._process() accumulates delta and calls queue_redraw() 12 times a
## second whenever a level has water or an animated tile -- which is every
## level, since every level has fire. Pausing never stopped it: `paused` only
## freezes tick_timer, so the board went on repainting a picture nobody could
## see, behind an opaque popup, while the platform wake lock held the display
## at full brightness. A player who hits Pause and puts the phone down face-up
## gets a bright screen redrawing until the battery notices.
##
## Driven from _process() rather than from each of the places that show or
## hide a panel, so a new panel -- or a new route to an existing one -- cannot
## silently leave the heartbeat running. The cost is four boolean reads a
## frame. The failure mode of the alternative is a board that stops animating
## and nobody notices, which is far worse than the thing being fixed.
func _update_board_animation() -> void:
	if board == null:
		return
	var covered := paused \
		or (intro_panel != null and intro_panel.visible) \
		or (win_panel != null and win_panel.visible) \
		or (lose_panel != null and lose_panel.visible)
	board.set_process(not covered)


## True if `coord` currently holds an unspent Bomb Catapult block -- the
## precondition for treating a press there as a possible aim-and-fire
## sequence instead of ordinary tap-to-place/pickup handling. A catapult
## that already fired is gone from board.placed_blocks entirely (see
## HexBoard.fire_catapult()), so this naturally returns false for a spent
## one without any extra bookkeeping.
func _is_live_catapult(coord: Vector2i) -> bool:
	if not board.placed_blocks.has(coord):
		return false
	var block: BlockData = block_catalog[board.placed_blocks[coord]]
	return block.behavior == BlockData.TickBehavior.CATAPULT


## Recomputes the current aim direction (from wherever the player's
## finger/cursor last was, relative to the catapult's own screen position,
## snapped to the nearest of the 6 hex directions) and the current charged
## distance (grows by one tile every CATAPULT_CHARGE_MSEC_PER_TILE msec of
## holding, capped at HexBoard.CATAPULT_MIN_RANGE + CATAPULT_MAX_EXTRA_RANGE),
## then pushes both to the board so HexBoard._draw_catapult_aim() can
## preview them. Called every frame while _catapult_aiming is true.
func _update_catapult_aim() -> void:
	var catapult_center_local := Hex.axial_to_pixel(_catapult_press_coord)
	var catapult_center_screen: Vector2 = board.to_global(catapult_center_local)
	var to_finger := _catapult_last_drag_pos - catapult_center_screen
	if to_finger.length() > 4.0: # ignore jitter right at the catapult's own center -- keep the last real direction
		_catapult_direction = _snap_to_hex_direction(to_finger)

	_catapult_last_distance = _current_catapult_distance()
	board.set_catapult_aim(_catapult_press_coord, _catapult_direction, _catapult_last_distance)


## Tiles out from the catapult the current charge has reached --
## HexBoard.CATAPULT_MIN_RANGE plus one tile per CATAPULT_CHARGE_MSEC_PER_TILE
## msec held so far, capped at CATAPULT_MAX_EXTRA_RANGE extra tiles.
func _current_catapult_distance() -> int:
	var held_msec := Time.get_ticks_msec() - _catapult_charge_started_msec
	var extra := int(floor(held_msec / float(CATAPULT_CHARGE_MSEC_PER_TILE)))
	extra = mini(extra, HexBoard.CATAPULT_MAX_EXTRA_RANGE)
	return HexBoard.CATAPULT_MIN_RANGE + extra


## Snaps a screen-space offset (finger/cursor position minus the
## catapult's own screen position) to whichever of the 6 hex directions
## its angle is closest to, by comparing it against each direction's own
## pixel offset (Hex.axial_to_pixel() applied to the direction vector
## itself gives that direction's screen-space bearing) via a dot-product
## nearest-match -- good enough for aiming since we only care which of 6
## angular buckets the touch falls in, not a precise coordinate.
func _snap_to_hex_direction(screen_offset: Vector2) -> Vector2i:
	var best_dir := Hex.NEIGHBOR_OFFSETS[0]
	var best_dot := -INF
	var offset_normalized := screen_offset.normalized()
	for dir in Hex.NEIGHBOR_OFFSETS:
		var dir_bearing := Hex.axial_to_pixel(dir).normalized()
		var dot := offset_normalized.dot(dir_bearing)
		if dot > best_dot:
			best_dot = dot
			best_dir = dir
	return best_dir


## Shifts the board vertically by `delta` px, clamped so its top edge never
## scrolls below its resting position (top_position_y) and its bottom edge
## never scrolls up past what max_scroll_down allows -- see
## HexBoard._fit_hex_layout().
func _scroll_by(delta: float) -> void:
	var min_y := board.top_position_y - board.max_scroll_down
	var max_y := board.top_position_y
	board.position.y = clampf(board.position.y + delta, min_y, max_y)


func _handle_tap(screen_pos: Vector2) -> void:
	var local_pos: Vector2 = board.to_local(screen_pos)
	var coord := board.screen_to_hex(local_pos)

	# Hydro Electric Power Plant: a second tap landing on the SAME hex
	# within DOUBLE_TAP_WINDOW_MSEC of the first counts as a double-tap,
	# which activates the plant if it's "ready" -- i.e. water has already
	# reached it (see HexBoard.hydro_ready_at()/try_activate_hydro()).
	# Tried first, same "no-op everywhere it doesn't apply" pattern dig()
	# below uses: try_activate_hydro() itself already returns false for
	# any coord that isn't a ready plant, so this changes nothing on any
	# level/cell without one. The single FIRST tap of a pair still falls
	# through to the normal handling below (dig/pickup/place) exactly as
	# before -- a Hydro Plant cell's terrain is HYDRO, not DIRT, and it
	# never has a placed_blocks entry, so a lone tap on one is already a
	# harmless no-op today, nothing to change there.
	var now := Time.get_ticks_msec()
	var is_double_tap := coord == _last_tap_coord and (now - _last_tap_msec) <= DOUBLE_TAP_WINDOW_MSEC
	_last_tap_coord = coord
	_last_tap_msec = now
	if is_double_tap and board.try_activate_hydro(coord):
		_last_tap_coord = Vector2i(99999, 99999) # consume -- a 3rd quick tap shouldn't chain into another activation attempt
		return

	# "Dig the River": tapping a packed-dirt cell digs it -- 3 taps opens
	# it (see HexBoard.dig() / DIG_TAPS_REQUIRED). Tried first, before the
	# block pickup/placement handling below, and dig() itself returns
	# false for any non-dirt cell, so this is a no-op on every cell (and
	# every level) without dirt. Digging is free and unlimited -- it never
	# touches inventory, so no label refresh is needed -- but it only works
	# once the water is actually flowing: HexBoard.dig() refuses every tap
	# before Start, so a dig level can't be pre-carved during the planning
	# phase. A dirt tap during planning falls through everything below and
	# does nothing at all (place_block() rejects DIRT terrain too).
	if board.dig(coord):
		return

	# Tapping a cell that already has a block picks it up (refunding it to
	# inventory) regardless of what's currently selected -- this is the
	# "undo a placement" affordance, and it works in real time whether or
	# not water is actively flowing. Only an empty cell with something
	# selected falls through to placing a new block.
	#
	# block_anchors, not just placed_blocks. Post-Start a placement is QUEUED
	# until the next PLACEMENT beat, so for up to a full measure the block
	# exists only in pending_placements -- visibly, as the ghost _draw_cell()
	# paints. Testing placed_blocks alone meant the undo affordance was dead
	# for exactly that measure: the player taps a hex, sees the ghost appear,
	# realises within the same second that it is one row off, taps it again
	# and nothing happens. block_anchors is written at queue time by
	# place_block() for every cell of the footprint, so this also picks up
	# either half of a 2-wide Wall, and remove_block() already knows how to
	# cancel a pending placement (it refunds once, not once per cell).
	#
	# Safe against stale entries: every removal path erases block_anchors --
	# immediately pre-Start, and in resolve_placement_phase() for a queued
	# one -- so the only cells with an anchor and no placed_blocks entry are
	# precisely the pending placements this is meant to catch.
	if board.placed_blocks.has(coord) or board.block_anchors.has(coord):
		if board.remove_block(coord):
			_refresh_inventory_labels()
		return

	# Delete mode (see delete_mode): also lets a tap cancel a block that is
	# still queued for the next PLACEMENT beat (remove_block() handles the
	# pending case itself), and a tap that didn't land on anything is
	# simply a miss -- never fall through to placing something.
	if delete_mode:
		if board.remove_block(coord):
			_refresh_inventory_labels()
		return

	if board.selected_block_id == "":
		return

	if board.place_block(coord, board.selected_block_id):
		_refresh_inventory_labels()


## Fires every constant SUBTICK_INTERVAL -- purely a heartbeat. Only every
## ticks_per_beat-th fire actually advances the game to the next beat phase
## (see _advance_beat()); the sub-ticks in between currently do nothing, but
## are the hook point for future per-sub-tick animation/audio pulses (see
## the "Music-driven timing spec" doc).
func _on_subtick() -> void:
	_subtick_count += 1
	if _subtick_count < ticks_per_beat:
		return
	_subtick_count = 0
	_advance_beat()


## Runs the current beat's phase on the board, then advances current_beat to
## the next one in the 1-2-3-4 cycle (wrapping back to PLACEMENT after
## STATUS). See the beat-cycle doc comment above the var declarations for
## what each phase does.
func _advance_beat() -> void:
	match current_beat:
		BeatPhase.PLACEMENT:
			board.resolve_placement_phase()
		BeatPhase.WATER:
			board.resolve_water_phase()
		BeatPhase.TERRAIN:
			board.resolve_terrain_phase()
		BeatPhase.STATUS:
			# The measure completes on this beat. Counted BEFORE resolving,
			# because resolve_status_phase() is what fires the win, and
			# _on_level_won() has to see a total that includes this measure.
			measures_elapsed += 1
			board.resolve_status_phase()
	_update_status_label()
	current_beat = (current_beat % BeatPhase.STATUS) + 1


func _update_status_label() -> void:
	status_label.text = "Fires remaining: %d" % board.fires_remaining


## On a win, stop the timer, mark the level complete, and pop up the
## "Success!" panel (see win_panel above) with a single Next button --
## replaces the old behavior of a status-label message plus an automatic,
## timed return to Level Select. The player now explicitly taps Next
## (see _on_win_next_pressed()) rather than the scene changing out from
## under them a second and a half later.
func _on_level_won() -> void:
	tick_timer.stop()
	pause_button.disabled = true
	status_label.text = "Level complete!"
	GameState.mark_level_complete(level_data.level_id)

	# Optional rewards. Neither is ever required to finish a level; both are
	# recorded on a win and reported here. A level with neither shows
	# nothing at all.
	var notes: Array[String] = []

	# Hydro Plant: was it running as the level ended?
	if board.has_hydro_plants():
		var earned := board.all_hydro_plants_running()
		if earned:
			GameState.mark_hydro_bonus(level_data.level_id)
			notes.append("Bonus: power plant running")
		else:
			notes.append("Bonus missed: the power plant never ran")

	# Par: finishing inside the target opens this level's side path on the
	# map (see LevelSelect.BONUS_FORKS). Only the ten fork levels set one.
	if level_data.par_measures > 0:
		if measures_elapsed <= level_data.par_measures:
			GameState.mark_par(level_data.level_id)
			notes.append("Par met in %d measures — side path open" % measures_elapsed)
		else:
			notes.append("Par missed: %d measures, par is %d"
				% [measures_elapsed, level_data.par_measures])

	win_bonus_label.visible = not notes.is_empty()
	win_bonus_label.text = "\n".join(notes)

	# Next's label reflects what it's actually about to do: "Next" when
	# there's another level after this one in LevelSelect.LEVEL_PATHS,
	# "Level Select" when this was the last level and there's nowhere
	# further to advance to.
	var has_next := _next_level_path() != ""
	win_next_button.icon = NEXT_ICON if has_next else EXIT_ICON
	win_next_button.tooltip_text = "Next level" if has_next else "Level Select"
	win_panel.visible = true


## Looks up this scene's level (_level_path, captured at _ready()) in
## LevelSelect.LEVEL_PATHS and returns the path immediately after it, or
## "" if this level isn't found there (shouldn't normally happen) or is
## the last entry. LevelSelect.LEVEL_PATHS is reachable directly as a
## global class constant (LevelSelect.gd declares `class_name LevelSelect`)
## without needing an instance of that scene.
func _next_level_path() -> String:
	# campaign_paths(), not LEVEL_PATHS: the tutorial runs ahead of level 1,
	# so "next" after the last tutorial is level 1 rather than nowhere.
	var paths := LevelSelect.campaign_paths()
	var idx := paths.find(_level_path)
	if idx == -1 or idx + 1 >= paths.size():
		return ""
	return paths[idx + 1]


## Advances past the win popup. If there's a next level, queues it up
## (GameState.pending_level_path) and reloads this same Level.tscn scene --
## which naturally re-runs _ready() from scratch, including showing that
## next level's own intro popup, exactly as if the player had picked it
## from Level Select. If this was the last level, there's nothing to
## advance to, so it just returns to Level Select instead (this is also
## what the button is labeled in that case -- see _on_level_won()).
func _on_win_next_pressed() -> void:
	var next_path := _next_level_path()
	if next_path == "":
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
		return
	GameState.pending_level_path = next_path
	get_tree().change_scene_to_file("res://scenes/Level.tscn")


## On a loss, stop the timer and pop up the small Retry / Level Select
## panel (see lose_panel above) with a reason-specific message. With no
## HUD Retry button any more this panel is the only Retry available at
## that point, so it is both the prompt and the way out. The HUD's Back
## button still works underneath it.
func _on_level_lost() -> void:
	tick_timer.stop()
	pause_button.disabled = true
	match board.lose_reason:
		HexBoard.LoseReason.TOWN:
			status_label.text = "The town flooded!"
			lose_reason_label.text = "The town flooded!"
		HexBoard.LoseReason.EDGE:
			status_label.text = "Water overflowed the bottom edge!"
			lose_reason_label.text = "Water overflowed the bottom edge!"
		_:
			status_label.text = "Flooded!"
			lose_reason_label.text = "Flooded!"
	lose_panel.visible = true
