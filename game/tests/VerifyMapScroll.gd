extends Node

## Headless check that Level Select opens on the player's own progress, and
## that the HUD's two readouts are legible. Run from the game/ directory:
##   godot --headless res://tests/VerifyMapScroll.tscn
##
## Level Select used to slam the scroll to the bottom -- Level 1 -- every time
## it was built, which is every cold start, every return from a level and every
## Back. A player on level 47 landed two and a half screen-heights below their
## own progress and had to drag up to it, every time.
##
## The regression risk runs the other way: a fresh save must STILL open at the
## bottom, because that is where Level 1 is. Both directions are checked.
##
## Runs on a scratch save slot, not slot 0 -- see the warning in CLAUDE.md
## about the suites overwriting a real save.

const TEST_SLOT := 98

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


## Builds Level Select with progress up to `highest`, and reports where it
## scrolled to and where that level's node actually sits.
func _open_at(highest: int, last_played: String = "") -> Dictionary:
	GameState.load_slot(TEST_SLOT) # clears last_played_level_path, by design
	GameState.last_played_level_path = last_played
	GameState.highest_unlocked_level = highest
	GameState.debug_unlock_all = false
	var select: Node = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(select)
	for i in range(8):
		await get_tree().process_frame
	var scroll: ScrollContainer = select.get_node("ScrollContainer")
	var node: Control = select.get_node("ScrollContainer/MapRoot").get_node_or_null(
		"level_%d" % highest)
	var out := {
		"scroll": scroll.scroll_vertical,
		"max": int(maxf(select.get_node("ScrollContainer/MapRoot").size.y - scroll.size.y, 0.0)),
		"viewport": scroll.size.y,
		"node_y": node.position.y + node.size.y * 0.5 if node else -1.0,
	}
	select.queue_free()
	remove_child(select)
	await get_tree().process_frame
	return out


## Same as _open_at(), but reports where an ARBITRARY node sits rather than
## the one matching the player's progress -- used to check what a given save
## actually lands on.
func _open_on_node(highest: int, node_name: String, last_played: String = "") -> Dictionary:
	GameState.load_slot(TEST_SLOT) # clears last_played_level_path, by design
	GameState.last_played_level_path = last_played
	GameState.highest_unlocked_level = highest
	GameState.debug_unlock_all = false
	var select: Node = load("res://scenes/LevelSelect.tscn").instantiate()
	add_child(select)
	for i in range(8):
		await get_tree().process_frame
	var scroll: ScrollContainer = select.get_node("ScrollContainer")
	var node: Control = select.get_node("ScrollContainer/MapRoot").get_node_or_null(node_name)
	var out := {
		"scroll": float(scroll.scroll_vertical),
		"max": maxf(select.get_node("ScrollContainer/MapRoot").size.y - scroll.size.y, 0.0),
		"viewport": scroll.size.y,
		"node_y": node.position.y + node.size.y * 0.5 if node else -1.0,
	}
	select.queue_free()
	remove_child(select)
	await get_tree().process_frame
	return out


func _ready() -> void:
	GameState.debug_unlock_all = false
	GameState.delete_slot(TEST_SLOT)
	GameState.last_played_level_path = ""

	print("A fresh save opens at the bottom -- now on Tutorial 1")
	var fresh := await _open_at(1)
	_check(fresh["scroll"] >= fresh["max"] - 1,
		"scrolled to the bottom (%d of max %d)" % [fresh["scroll"], fresh["max"]])
	var first_tutorial: LevelData = load(LevelSelect.TUTORIAL_PATHS[0])
	var t1 := await _open_on_node(1, "level_%d" % first_tutorial.level_id)
	_check(t1["node_y"] >= t1["scroll"] and t1["node_y"] <= t1["scroll"] + t1["viewport"],
		"Tutorial 1's node is on screen for a new save")

	# The gate on that: a player who skipped the tutorial and is deep in the
	# campaign must NOT be thrown back down to it, which is what an
	# ungated "open on the first unfinished tutorial" rule does -- their
	# tutorial nodes stay unfinished forever.
	print("A player who skipped the tutorial is not dragged back to it")
	var skipper := await _open_on_node(82, "level_%d" % first_tutorial.level_id)
	_check(skipper["node_y"] < skipper["scroll"]
			or skipper["node_y"] > skipper["scroll"] + skipper["viewport"],
		"Tutorial 1 is off screen for a level-82 player")

	print("A player partway up opens on their own level")
	for level in [24, 47, 82]:
		var at := await _open_at(level)
		var top: float = at["scroll"]
		var bottom: float = top + at["viewport"]
		_check(at["node_y"] >= top and at["node_y"] <= bottom,
			"level %d's node (y=%.0f) is on screen (%.0f..%.0f)"
				% [level, at["node_y"], top, bottom])
		# and roughly centred, not merely just-in-frame
		var centre: float = top + at["viewport"] * 0.5
		_check(absf(at["node_y"] - centre) <= at["viewport"] * 0.25,
			"...and near the middle of the view, not clinging to an edge")

	print("Leaving a level brings the map back centred on THAT level")
	# Replaying level 24 with the campaign at 82 used to land the player back
	# at 82 -- the map only knew about progress, not about where they had
	# just been. Level.gd records itself on _ready(); here it is set directly
	# so the test does not depend on the Level scene.
	var back := await _open_on_node(82, "level_24", LevelSelect.LEVEL_PATHS[23])
	var back_centre: float = back["scroll"] + back["viewport"] * 0.5
	_check(absf(back["node_y"] - back_centre) <= back["viewport"] * 0.25,
		"after leaving level 24, the map is centred on level 24 (progress at 82)")

	# The same for a tutorial, whose slot is not its id. Tutorial 3 is the
	# third node from the bottom of the trail, so centring it exactly would
	# mean scrolling past the end of the map -- the honest requirement is
	# "on screen, with the scroll at its limit", not "dead centre".
	var t3: LevelData = load(LevelSelect.TUTORIAL_PATHS[2])
	var back_t := await _open_on_node(82, "level_%d" % t3.level_id, LevelSelect.TUTORIAL_PATHS[2])
	_check(back_t["node_y"] >= back_t["scroll"]
			and back_t["node_y"] <= back_t["scroll"] + back_t["viewport"],
		"after leaving tutorial 3, tutorial 3 is on screen")
	_check(back_t["scroll"] >= back_t["max"] - 1.0,
		"...scrolled as far toward it as the map allows (%.0f of %.0f)" % [back_t["scroll"], back_t["max"]])

	# And it beats the brand-new-save tutorial rule too: a new player who
	# opens level 1 and backs out should see level 1, not be sent to T1.
	var back_new := await _open_on_node(1, "level_1", LevelSelect.LEVEL_PATHS[0])
	var n_centre: float = back_new["scroll"] + back_new["viewport"] * 0.5
	_check(absf(back_new["node_y"] - n_centre) <= back_new["viewport"] * 0.25,
		"a new player who backs out of level 1 lands on level 1")

	# An unknown path is ignored rather than crashing or scrolling somewhere
	# odd, and a slot switch clears the record entirely.
	var ignored := await _open_at(47, "res://data/levels/does_not_exist.tres")
	var ignored_centre: float = ignored["scroll"] + ignored["viewport"] * 0.5
	_check(absf(ignored["node_y"] - ignored_centre) <= ignored["viewport"] * 0.25,
		"an unknown last-played path falls back to progress")
	GameState.last_played_level_path = LevelSelect.LEVEL_PATHS[23]
	GameState.load_slot(TEST_SLOT)
	_check(GameState.last_played_level_path == "", "switching save slot forgets the last level")

	print("Level 100 clamps to the top rather than overshooting")
	var top_end := await _open_at(100)
	_check(top_end["scroll"] >= 0, "scroll is not negative (%d)" % top_end["scroll"])
	_check(top_end["scroll"] <= top_end["max"], "scroll is within range")

	GameState.delete_slot(TEST_SLOT)

	print("The HUD readouts carry an outline")
	# White on sky blue measured 1.73:1, and on grass 2.75:1 -- both fail WCAG,
	# and BudgetLabel is the ONLY place the remaining block count appears on a
	# shared-budget level. An outline is what LevelSelect's group headers
	# already use; this pins the HUD to the same treatment.
	GameState.load_slot(TEST_SLOT)
	GameState.pending_level_path = "res://data/levels/level_019.tres"
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	for i in range(6):
		await get_tree().process_frame
	for name in ["StatusLabel", "BudgetLabel"]:
		var label: Label = level.get_node("UI/HUD/" + name)
		_check(label.get_theme_constant("outline_size") >= 4,
			"%s has an outline (size %d)" % [name, label.get_theme_constant("outline_size")])
		_check(label.get_theme_color("font_outline_color").a > 0.5,
			"%s's outline is opaque enough to read" % name)
	level.queue_free()
	remove_child(level)
	await get_tree().process_frame
	GameState.delete_slot(TEST_SLOT)

	if _failures == 0:
		print("MAP SCROLL PASS")
	else:
		printerr("MAP SCROLL FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
