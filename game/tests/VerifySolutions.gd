extends Node

## Replays every level in level-solutions.md through LevelSim and checks it
## still wins on the documented measure. Run from game/:
##   godot --headless res://tests/VerifySolutions.tscn

func _ready() -> void:
	var sim := LevelSim.new()
	add_child(sim)
	var catalog := LevelSim.load_block_catalog()
	var solutions := LevelSim.parse_solutions()
	print("parsed %d block types, %d solutions" % [catalog.size(), solutions.size()])

	var pass_count := 0
	var fail: Array = []
	var only_from := int(OS.get_environment("FROM")) if OS.get_environment("FROM") != "" else 1
	var only_to := int(OS.get_environment("TO")) if OS.get_environment("TO") != "" else LevelSelect.LEVEL_PATHS.size()
	for n in range(only_from, only_to + 1):
		if not solutions.has(n):
			continue
		var started_msec := Time.get_ticks_msec()
		var level_data: LevelData = load(LevelSelect.LEVEL_PATHS[n - 1])
		var entry: Dictionary = solutions[n]
		var r := sim.simulate(level_data, catalog, entry["placements"])
		var expected: int = entry["win"]
		print("  level %d: won=%s measures=%d expected=%d (%dms)"
			% [n, r["won"], r["measures"], expected, Time.get_ticks_msec() - started_msec])
		if r["won"] and (expected < 0 or r["measures"] == expected):
			pass_count += 1
		else:
			fail.append("Level %d: won=%s measures=%d expected=%d reason=%s placed_all=%s"
				% [n, r["won"], r["measures"], expected, r["reason"], r["placed_all"]])

	print("solutions reproduced: %d" % pass_count)
	print("mismatches: %d" % fail.size())
	for f in fail:
		print("  ", f)
	get_tree().quit(0 if fail.is_empty() else 1)
