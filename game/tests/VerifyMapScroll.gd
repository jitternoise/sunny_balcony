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
func _open_at(highest: int) -> Dictionary:
	GameState.load_slot(TEST_SLOT)
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


func _ready() -> void:
	GameState.debug_unlock_all = false
	GameState.delete_slot(TEST_SLOT)

	print("A fresh save still opens at the bottom (Level 1)")
	var fresh := await _open_at(1)
	_check(fresh["scroll"] >= fresh["max"] - 1,
		"scrolled to the bottom (%d of max %d)" % [fresh["scroll"], fresh["max"]])

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
