extends Node

## Regression test for the optional Hydro Plant bonus. For every level that
## ships a plant it proves three things, and for every level that does not
## it proves the feature is absent entirely:
##   1. the plant does not change the level -- the documented solution
##      still wins on exactly the documented measure with the plant inert,
##      and the bonus reads as unearned in that run;
##   2. water actually reaches the plant, so the bonus can be attempted;
##   3. some activation timing switches the plant on AND still wins, so the
##      bonus is earnable rather than a trap.
## Run from game/:  godot --headless res://tests/VerifyHydroBonus.tscn

## The levels that ship a Hydro Plant, and the centre cell each one sits on.
## Kept here as the expected shipping state so an accidental edit to a
## level's .tres shows up as a failure rather than passing silently.
const PLANT_LEVELS := {
	7: Vector2i(-1, 2),
	13: Vector2i(1, -2),
	18: Vector2i(-5, 0),
	25: Vector2i(0, -2),
	33: Vector2i(-3, 1),
	52: Vector2i(0, -2),
	63: Vector2i(-1, 0),
	82: Vector2i(2, -4),
}

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	var sim := LevelSim.new()
	add_child(sim)
	var catalog := LevelSim.load_block_catalog()
	var solutions := LevelSim.parse_solutions()

	for n in PLANT_LEVELS.keys():
		var path: String = LevelSelect.LEVEL_PATHS[n - 1]
		var data: LevelData = load(path)
		print("Level %d" % n)
		_check(data.hydro_plant_cells.size() == 1 and data.hydro_plant_cells[0] == PLANT_LEVELS[n],
			"level %d ships its plant at %s" % [n, PLANT_LEVELS[n]])
		if not solutions.has(n):
			_check(false, "level %d has a parsable documented solution" % n)
			continue
		var entry: Dictionary = solutions[n]

		# 1. The plant must not change how the level plays.
		var inert := sim.simulate(data, catalog, entry["placements"])
		_check(inert["won"] and inert["measures"] == entry["win"],
			"level %d still wins on measure %d with the plant inert" % [n, entry["win"]])
		_check(inert["has_plants"] and not inert["all_running"],
			"level %d reports the bonus unearned when the plant is left alone" % n)

		# 2. Water has to reach the plant for the bonus to be attemptable.
		_check(inert["touched"], "level %d's plant is reached by water" % n)

		# 3. Some activation timing earns the bonus AND still wins.
		var earned_at := -1
		for delay in range(0, 8):
			var on := sim.simulate(data, catalog, entry["placements"],
				PLANT_LEVELS[n], true, 300, delay)
			if on["activated"] and on["won"] and on["all_running"]:
				earned_at = delay
				break
		_check(earned_at >= 0,
			"level %d can be won with its plant running (waiting %d measures)" % [n, earned_at])

	# Every other level must be untouched by the feature.
	var plain_without_plants := 0
	for n in range(1, LevelSelect.LEVEL_PATHS.size() + 1):
		if PLANT_LEVELS.has(n):
			continue
		var data: LevelData = load(LevelSelect.LEVEL_PATHS[n - 1])
		if data.hydro_plant_cells.is_empty():
			plain_without_plants += 1
	_check(plain_without_plants == LevelSelect.LEVEL_PATHS.size() - PLANT_LEVELS.size(),
		"every other level ships with no plant at all")

	if _failures == 0:
		print("HYDRO BONUS PASS")
	else:
		printerr("HYDRO BONUS FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
