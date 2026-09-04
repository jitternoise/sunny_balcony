extends SceneTree

## Replays every documented solution in level-solutions.md against the real
## engine and reports which ones still win, and in how many measures.
##
##   godot --headless --path game --script res://tools/verify_solutions.gd \
##         -- ../level-solutions.md [--verbose]
##
## The solutions file lives at the repository root, outside res://, so its
## path is passed in rather than hardcoded. A relative path is resolved
## against the project directory.
##
## Why this exists: the 2026-08-31 change making the Wall 2 tiles wide
## invalidated every solution that places one -- 49 of 100 -- because each
## now covers a cell it wasn't verified with. This replays them against the
## engine that actually ships, so the answer can't drift from the game the
## way the old Python port did.

const BLOCK_NAMES := {
	"wall": "wall",
	"splitter": "splitter",
	"divert-right": "divert_right",
	"diverter-right": "divert_right",
	"divert-left": "divert_left",
	"diverter-left": "divert_left",
	"catapult": "bomb_catapult",
	"bomb-catapult": "bomb_catapult",
}

## Generous ceiling -- the slowest documented solution wins at measure 103.
const MAX_MEASURES := 200


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <path-to-level-solutions.md> [--verbose]")
		quit(2)
		return
	var verbose := args.has("--verbose")

	var path: String = args[0]
	if path.is_relative_path():
		path = ProjectSettings.globalize_path("res://").path_join(path).simplify_path()
	if not FileAccess.file_exists(path):
		print("no solutions file at: ", path)
		quit(2)
		return

	var sim := FFSim.new()
	get_root().add_child(sim)

	var line_re := RegEx.create_from_string(
		"^- \\*\\*(?:Level )?(\\d+)\\.?[^*]*\\*\\*(?: \\([^)]*\\))? — (.+?) \\| win (\\d+)\\s*$")
	var placement_re := RegEx.create_from_string("([A-Za-z][A-Za-z-]*)\\s*\\((-?\\d+),\\s*(-?\\d+)\\)")
	var coord_re := RegEx.create_from_string("\\((-?\\d+),\\s*(-?\\d+)\\)")

	var pass_exact := []
	var pass_diff := []
	var failed := []
	var skipped := []

	for line in FileAccess.get_file_as_string(path).split("\n"):
		var m := line_re.search(line)
		if m == null:
			continue
		var level := int(m.get_string(1))
		var body := m.get_string(2)
		var documented := int(m.get_string(3))
		var level_path := "res://data/levels/level_%03d.tres" % level

		var plan := {"max_measures": MAX_MEASURES}
		var placements := []
		var digs := []

		# A solution can mix both: "divert-right (3, -6) + divert-left
		# (2, -2) + dig 4 cells: [(-2, 6), ...]". Split at the first "dig"
		# so the block placements and the dug cells are each parsed from
		# their own half -- treating the line as one or the other silently
		# drops half the solution.
		var dig_at := body.find("dig")
		var place_part := body if dig_at == -1 else body.substr(0, dig_at)
		var dig_part := "" if dig_at == -1 else body.substr(dig_at)

		var bad_name := false
		for p in placement_re.search_all(place_part):
			var name := p.get_string(1).to_lower()
			if not BLOCK_NAMES.has(name):
				skipped.append("%3d  unrecognised placement \"%s\" in: %s" % [level, name, body])
				bad_name = true
				break
			placements.append({
				"coord": Vector2i(int(p.get_string(2)), int(p.get_string(3))),
				"block": BLOCK_NAMES[name],
			})
		if bad_name:
			continue

		for c in coord_re.search_all(dig_part):
			digs.append(Vector2i(int(c.get_string(1)), int(c.get_string(2))))

		if placements.is_empty() and digs.is_empty():
			skipped.append("%3d  prose solution, not machine-readable: \"%s\"" % [level, body])
			continue
		if not placements.is_empty():
			plan["placements"] = placements
		if not digs.is_empty():
			plan["digs"] = digs

		var r: Dictionary = sim.run(level_path, plan)
		var detail := "%s at measure %d (documented %d)  fires %d/%d  pools %d/%d" % [
			r.outcome, r.measures, documented,
			r.fires_total - r.fires_remaining, r.fires_total,
			r.pools_full, r.pools_total]
		if r.placements_rejected.size() > 0:
			detail += "  REJECTED: " + str(r.placements_rejected)
		if r.reason != "":
			detail += "  reason=" + r.reason

		var has_wall := false
		for p in placements:
			if p["block"] == "wall":
				has_wall = true
		var tag := " [wall]" if has_wall else ""

		if r.outcome == "win" and r.measures == documented:
			pass_exact.append("%3d  %s%s" % [level, detail, tag])
		elif r.outcome == "win":
			pass_diff.append("%3d  %s%s" % [level, detail, tag])
		else:
			failed.append("%3d  %s%s" % [level, detail, tag])

	print("\n================ solution verification ================")
	print("exact  (wins, measure matches) : %d" % pass_exact.size())
	print("drift  (wins, measure differs) : %d" % pass_diff.size())
	print("BROKEN (no longer wins)        : %d" % failed.size())
	print("skipped                        : %d" % skipped.size())

	if not failed.is_empty():
		print("\n--- BROKEN ---")
		for f in failed:
			print("  " + f)
	if not pass_diff.is_empty():
		print("\n--- DRIFT (still winnable, different measure count) ---")
		for f in pass_diff:
			print("  " + f)
	if not skipped.is_empty():
		print("\n--- SKIPPED ---")
		for f in skipped:
			print("  " + f)
	if verbose and not pass_exact.is_empty():
		print("\n--- EXACT ---")
		for f in pass_exact:
			print("  " + f)

	quit(1 if not failed.is_empty() else 0)
