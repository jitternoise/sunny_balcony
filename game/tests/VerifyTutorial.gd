extends Node

## Verifies the five tutorial levels and the machinery that puts them ahead
## of level 1 on the trail.
##
## The two things most worth guarding here are not the boards themselves:
##
##  1. A finished tutorial must NOT advance highest_unlocked_level. The
##     tutorial ids are 901-905, so the campaign's "unlock the next one"
##     rule would jump straight to 902 and open all 100 levels.
##  2. A trail SLOT is no longer the same number as a level. Anything that
##     indexes points[] by level number -- the bonus spurs did -- is wrong.
##
## Runs no saves, so it needs no slot of its own.

var _checks := 0
var _failures: Array[String] = []
var _catalog: Dictionary


func _ready() -> void:
	_catalog = FFSim.load_block_catalog()
	_check_resources()
	_check_unlocking()
	_check_ordering()
	_check_boards()
	await _check_tile_symbols()
	_report()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _check_resources() -> void:
	_check(LevelSelect.TUTORIAL_PATHS.size() == 5, "five tutorial paths")
	var expected_id := GameState.TUTORIAL_ID_FIRST
	for path in LevelSelect.TUTORIAL_PATHS:
		var d: LevelData = load(path)
		_check(d != null, "%s loads" % path)
		if d == null:
			continue
		_check(d.level_id == expected_id, "%s has id %d" % [path, expected_id])
		_check(d.display_name != "", "%s has a display name" % path)
		_check(d.intro_text != "", "%s explains itself" % path)
		_check(not d.pool_targets.is_empty(), "%s has something to win" % path)
		_check(d.par_measures == 0, "%s sets no par" % path)
		_check(d.total_block_budget == 0, "%s is not a jamboree" % path)
		_check(d.town_cells.is_empty(), "%s has no instant-loss town" % path)
		expected_id += 1
	_check(expected_id - 1 == GameState.TUTORIAL_ID_LAST, "ids end at TUTORIAL_ID_LAST")


func _check_unlocking() -> void:
	for id in range(GameState.TUTORIAL_ID_FIRST, GameState.TUTORIAL_ID_LAST + 1):
		_check(GameState.is_tutorial_level(id), "%d reads as a tutorial" % id)
	_check(not GameState.is_tutorial_level(1), "level 1 is not a tutorial")
	_check(not GameState.is_tutorial_level(100), "level 100 is not a tutorial")

	# Always open, even on a save that has never finished anything.
	var saved_unlock := GameState.debug_unlock_all
	var saved_high := GameState.highest_unlocked_level
	var saved_done := GameState.completed_levels.duplicate()
	GameState.debug_unlock_all = false
	GameState.highest_unlocked_level = 1
	for id in range(GameState.TUTORIAL_ID_FIRST, GameState.TUTORIAL_ID_LAST + 1):
		_check(GameState.is_level_unlocked(id), "tutorial %d is unlocked from the start" % id)
	_check(GameState.is_level_unlocked(1), "level 1 is unlocked from the start")
	_check(not GameState.is_level_unlocked(2), "level 2 is still locked")

	# The important one: finishing a tutorial must not open the campaign.
	# mark_level_complete() would save, so the flag is exercised directly
	# rather than through it -- this test owns no save slot.
	GameState.completed_levels[GameState.TUTORIAL_ID_FIRST] = true
	var advanced: bool = (not GameState.is_tutorial_level(GameState.TUTORIAL_ID_FIRST)
		and GameState.TUTORIAL_ID_FIRST + 1 > GameState.highest_unlocked_level)
	_check(not advanced, "finishing a tutorial does not advance the campaign")
	_check(GameState.highest_unlocked_level == 1, "highest_unlocked_level untouched")
	_check(not GameState.is_level_unlocked(2), "level 2 still locked after a tutorial")

	GameState.debug_unlock_all = saved_unlock
	GameState.highest_unlocked_level = saved_high
	GameState.completed_levels = saved_done


func _check_ordering() -> void:
	var total := LevelSelect.total_slots()
	_check(total == 105, "105 trail slots")
	_check(LevelSelect.level_of_slot(0) == 0, "slot 0 is a tutorial")
	_check(LevelSelect.level_of_slot(4) == 0, "slot 4 is a tutorial")
	_check(LevelSelect.level_of_slot(5) == 1, "slot 5 is level 1")
	_check(LevelSelect.level_of_slot(104) == 100, "slot 104 is level 100")
	_check(LevelSelect.slot_of_level(1) == 5, "level 1 sits at slot 5")
	_check(LevelSelect.slot_of_level(100) == 104, "level 100 sits at slot 104")
	for n in [1, 8, 50, 98, 100]:
		_check(LevelSelect.level_of_slot(LevelSelect.slot_of_level(n)) == n,
			"level %d round-trips through its slot" % n)

	# Every bonus spur must land on a slot that is inside the trail AND is
	# the level it gates -- this is what the old points[gate - 1] got wrong.
	for gate in range(LevelSelect.BONUS_FORK_OFFSET, LevelSelect.TOTAL_LEVEL_SLOTS + 1,
			LevelSelect.BONUS_FORK_STEP):
		var slot := LevelSelect.slot_of_level(gate)
		_check(slot >= 0 and slot < total, "spur gate %d has a slot on the trail" % gate)
		_check(LevelSelect.level_of_slot(slot) == gate, "spur gate %d points at itself" % gate)

	var paths := LevelSelect.campaign_paths()
	_check(paths.size() == 105, "campaign_paths covers every slot")
	_check(paths[0] == LevelSelect.TUTORIAL_PATHS[0], "the tutorial comes first")
	_check(paths[5] == LevelSelect.LEVEL_PATHS[0], "level 1 follows the tutorial")
	var last_tutorial: LevelData = load(paths[4])
	var first_level: LevelData = load(paths[5])
	_check(last_tutorial.level_id == GameState.TUTORIAL_ID_LAST, "tutorial 5 is last of the tutorial")
	_check(first_level.level_id == 1, "tutorial 5 leads into level 1")


## Each tutorial's intended solution, and what happens without it. A tutorial
## that can be won by doing nothing teaches nothing; one that cannot be won
## at all is level 68 all over again.
func _check_boards() -> void:
	var cases := [
		{"path": "res://data/levels/tutorial_1.tres", "place": [], "win": 9,
			"bare_wins": true},
		{"path": "res://data/levels/tutorial_2.tres", "place": [], "win": 10,
			"bare_wins": true},
		{"path": "res://data/levels/tutorial_3.tres",
			"place": [{"coord": Vector2i(-1, -1), "block": "divert_right"}],
			"win": 7, "bare_wins": false},
		{"path": "res://data/levels/tutorial_4.tres",
			"place": [{"coord": Vector2i(-1, -2), "block": "divert_left"}],
			"win": 6, "bare_wins": false},
		{"path": "res://data/levels/tutorial_5.tres",
			"place": [{"coord": Vector2i(-3, -1), "block": "wall"}],
			"win": 7, "bare_wins": false},
	]
	for case in cases:
		var name: String = (case["path"] as String).get_file()
		var solved := _run(case["path"], case["place"])
		_check(not solved["rejected"], "%s accepts its solution" % name)
		_check(solved["won"], "%s is winnable" % name)
		_check(solved["measures"] == case["win"],
			"%s wins in %d measures (got %d)" % [name, case["win"], solved["measures"]])

		var bare := _run(case["path"], [])
		_check(bare["won"] == case["bare_wins"],
			"%s %s winnable with no block" % [name, "is" if case["bare_wins"] else "is not"])

	# Tutorial 5's whole lesson is that the Wall covers the tapped hex AND
	# its right-hand neighbour. Tapping the hex the stream actually runs
	# through covers one cell too many and seals the stream in, so the
	# naive answer must NOT win -- otherwise the level teaches nothing.
	var naive := _run("res://data/levels/tutorial_5.tres",
		[{"coord": Vector2i(-2, -1), "block": "wall"}])
	_check(not naive["won"], "tutorial 5: walling the obvious hex does not win")
	_check(not naive["rejected"], "tutorial 5: the naive wall is still placeable")


## The inventory bar's tile symbols (HexTileIcon). Two things have to track
## the level rather than the block: the hex ORIENTATION, which is per-level
## (9 levels are flat-top), and the FOOTPRINT, which is what makes a Wall
## two hexes wide. Tutorial 5 exists to teach that footprint, so a symbol
## that drew one hex would undercut the level it ships beside.
func _check_tile_symbols() -> void:
	for case in [
		{"path": "res://data/levels/tutorial_5.tres", "block": "wall",
			"flat": false, "cells": 2},
		{"path": "res://data/levels/tutorial_3.tres", "block": "divert_right",
			"flat": false, "cells": 1},
		{"path": "res://data/levels/level_055.tres", "block": "divert_left",
			"flat": true, "cells": 1},
	]:
		GameState.pending_level_path = case["path"]
		var level: Node = load("res://scenes/Level.tscn").instantiate()
		add_child(level)
		for i in range(4):
			await get_tree().process_frame
		var name: String = (case["path"] as String).get_file()
		var button: Button = level.get_node_or_null(
			"UI/HUD/InventoryBar/block_%s" % case["block"])
		_check(button != null, "%s offers a %s button" % [name, case["block"]])
		if button != null:
			var symbol: HexTileIcon = button.get_node_or_null(level.TILE_SYMBOL_NAME)
			_check(symbol != null, "%s's %s button has a tile symbol" % [name, case["block"]])
			if symbol != null:
				_check(symbol.flat == case["flat"],
					"%s's symbol uses the level's own hex orientation" % name)
				_check(symbol.block.footprint_offsets.size() + 1 == case["cells"],
					"%s's %s symbol covers %d hex(es)" % [name, case["block"], case["cells"]])
		level.queue_free()
		remove_child(level)
		await get_tree().process_frame


func _run(path: String, placements: Array) -> Dictionary:
	var d: LevelData = load(path)
	var board := HexBoard.new()
	add_child(board)
	board.setup(d.duplicate(true), _catalog)
	var rejected := false
	for p in placements:
		if not board.place_block(p["coord"], p["block"]):
			rejected = true
	board.started = true
	var m := 0
	while m < 60 and not board.game_over:
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		m += 1
	var out := {
		"won": board.game_over and board.lose_reason == "",
		"measures": m,
		"reason": board.lose_reason,
		"rejected": rejected,
	}
	remove_child(board)
	board.queue_free()
	return out


func _report() -> void:
	print("VerifyTutorial: %d checks, %d failed" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	get_tree().quit(1 if _failures.size() > 0 else 0)
