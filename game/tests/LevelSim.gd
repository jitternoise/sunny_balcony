extends Node
class_name LevelSim

## Headless simulation of a level, driven straight off HexBoard's four beat
## phases with no timers or scene involved. Used to prove that a level still
## plays out the way level-solutions.md documents -- in particular that
## adding a Hydro Plant to a level does not change its outcome.

const SOLUTIONS_PATH := "/home/user/sunny_balcony/level-solutions.md"

## The names level-solutions.md uses for each block, in all the spellings
## that file mixes ("Diverter-Right", "divert-right", "divert_right").
const BLOCK_ALIASES := {
	"wall": "wall",
	"splitter": "splitter",
	"diverter_right": "divert_right",
	"divert_right": "divert_right",
	"diverter_left": "divert_left",
	"divert_left": "divert_left",
	"catapult": "bomb_catapult",
	"bomb_catapult": "bomb_catapult",
}


static func load_block_catalog() -> Dictionary:
	var catalog := {}
	var dir := DirAccess.open("res://data/blocks")
	if dir == null:
		return catalog
	for file_name in dir.get_files():
		var name := file_name.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var block: BlockData = load("res://data/blocks/" + name)
		if block:
			catalog[block.id] = block
	return catalog


## Parses level-solutions.md into { level_number: {"placements": [...],
## "win": int} }. Lines whose solution is not a plain list of
## "name (q, r)" placements (the two dig levels) are skipped -- they are
## reported by the caller rather than silently treated as solved.
static func parse_solutions() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(SOLUTIONS_PATH):
		return out
	var text := FileAccess.open(SOLUTIONS_PATH, FileAccess.READ).get_as_text()
	# The file names levels two ways: "**Level 7**" early on, "**23. Diverter
	# Drills I**" from the group sections onward.
	var line_re := RegEx.create_from_string("^- \\*\\*(?:Level )?(\\d+)[^*]*\\*\\*[^—]*— (.+)$")
	var place_re := RegEx.create_from_string("([A-Za-z][A-Za-z-_]*)\\s*\\(\\s*(-?\\d+)\\s*,\\s*(-?\\d+)\\s*\\)")
	for raw in text.split("\n"):
		var m := line_re.search(raw.strip_edges())
		if m == null:
			continue
		var level_number := int(m.get_string(1))
		var body := m.get_string(2)
		var win_measure := -1
		var win_idx := body.find("| win ")
		if win_idx != -1:
			win_measure = int(body.substr(win_idx + 6).strip_edges())
			body = body.substr(0, win_idx)
		var placements: Array = []
		var parsed_ok := true
		for chunk in body.split("+"):
			chunk = chunk.strip_edges()
			if chunk.is_empty():
				continue
			var pm := place_re.search(chunk)
			if pm == null:
				parsed_ok = false
				break
			var key := pm.get_string(1).to_lower().replace("-", "_")
			if not BLOCK_ALIASES.has(key):
				parsed_ok = false
				break
			placements.append({
				"id": BLOCK_ALIASES[key],
				"coord": Vector2i(int(pm.get_string(2)), int(pm.get_string(3))),
			})
		if parsed_ok and not placements.is_empty():
			out[level_number] = {"placements": placements, "win": win_measure}
	return out


## Plays one level out. `plant_center` of Vector2i.MAX means "no plant".
## When `activate_hydro` is true the plant is switched on the first measure
## water has reached it, mimicking a player double-tapping it as soon as the
## ring appears.
func simulate(level_data: LevelData, catalog: Dictionary, placements: Array,
		plant_center: Vector2i = Vector2i.MAX, activate_hydro: bool = false,
		max_measures: int = 300, activate_delay: int = 0) -> Dictionary:
	var data: LevelData = level_data.duplicate(true)
	if plant_center != Vector2i.MAX:
		var cells: Array[Vector2i] = [plant_center]
		data.hydro_plant_cells = cells

	var board := HexBoard.new()
	add_child(board)
	board.setup(data, catalog)

	var placed_all := true
	for p in placements:
		if not board.place_block(p["coord"], p["id"]):
			placed_all = false
	board.started = true

	var activation_target := plant_center
	if activation_target == Vector2i.MAX and not board.hydro_plants.is_empty():
		activation_target = board.hydro_plants.keys()[0]

	var measures := 0
	var activated := false
	var ready_since := -1
	while measures < max_measures and not board.game_over:
		board.resolve_placement_phase()
		board.resolve_water_phase()
		# A player can switch the plant on any time after the ring appears;
		# activate_delay is how many measures they wait before doing so.
		if activate_hydro and not activated and activation_target != Vector2i.MAX:
			if board.hydro_ready_at(activation_target):
				if ready_since < 0:
					ready_since = measures
				if measures - ready_since >= activate_delay:
					activated = board.try_activate_hydro(activation_target)
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		measures += 1

	# Read the plant state off the board rather than off `plant_center`:
	# a level can ship its own plant, in which case no centre was injected
	# here and there is still a plant to report on.
	var touched := not board.hydro_plants.is_empty()
	var active := board.all_hydro_plants_running()
	for anchor in board.hydro_plants:
		if not (board.hydro_plants[anchor].get("touched", false) as bool):
			touched = false
			break

	var result := {
		"won": board.game_over and board.lose_reason == "",
		"lost": board.lose_reason != "",
		"reason": board.lose_reason,
		"measures": measures,
		"placed_all": placed_all,
		"touched": touched,
		"active": active,
		"activated": activated,
		"all_running": board.all_hydro_plants_running(),
		"has_plants": board.has_hydro_plants(),
	}
	board.queue_free()
	remove_child(board)
	return result
