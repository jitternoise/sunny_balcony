extends Node

## Headless check of the underground tunnel (LevelData.tunnel_pairs). From
## game/:
##   godot --headless res://tests/VerifyTunnels.tscn
##
## A tunnel is level terrain: an ENTRANCE that swallows every drop reaching
## it and an EXIT where each drop surfaces after travelling the straight
## underground line at the standard flow rate, one cell per WATER beat. So
## with d the hex distance between the two ends, a drop that would enter on
## WATER beat t is off the surface on t, sits ON the exit at the end of
## t + d, and falls from there on t + d + 1 by a spring's rule (DOWN_LEFT
## first on a pointy grid, straight down on a flat one). See
## HexBoard.tunnel_transit for the rule in full.
##
## Everything here drives a real HexBoard through the four beat phases in
## order, the way Level.gd and tools/Sim.gd do, on boards built in memory --
## no save is read or written. The last section plays the three sandbox
## levels (res://data/sandbox/) against ../sandbox-solutions.md.

const SMOKE_TEST := preload("res://tools/smoke_test.gd")
const LEVEL_SCRIPT := preload("res://scripts/gameplay/Level.gd")
const SANDBOX := ["tunnel_1", "tunnel_2", "tunnel_3"]

var _failures := 0
var _catalog: Dictionary


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	_catalog = FFSim.load_block_catalog()

	_check_timing()
	_check_continuous_stream()
	_check_diverter_and_splitter()
	_check_exit_parking()
	_check_blocks_refused()
	_check_two_tunnels()
	_check_flat_grid()
	_check_preview()
	_check_exit_arrow()
	_check_stones()
	_check_retry_resets()
	_check_event()
	_check_smoke_validation()
	_check_sandbox_levels()

	print("")
	if _failures == 0:
		print("TUNNELS PASS")
		get_tree().quit(0)
	else:
		print("TUNNELS FAIL -- %d check(s) failed" % _failures)
		get_tree().quit(1)


# --- building blocks --------------------------------------------------------

## A big open board with a far-off fire in the top corner, so a test run
## never wins (an empty objective list would win on the first STATUS beat)
## and never reaches the bottom edge in the beats it runs.
func _data(tunnels: Dictionary, sources: Array = [], inventory := {}, flat := false) -> LevelData:
	var data := LevelData.new()
	data.level_id = 999
	data.grid_radius = 8
	data.grid_style = "flat" if flat else "pointy"
	var typed: Array[Vector2i] = []
	for c in sources:
		typed.append(c)
	data.water_sources = typed
	var fire: Array[Vector2i] = [Vector2i(8, -8)]
	data.fire_cells = fire
	data.tunnel_pairs = tunnels
	data.starting_inventory = inventory
	return data


func _board(data: LevelData) -> HexBoard:
	var board := HexBoard.new()
	add_child(board)
	board.setup(data, _catalog)
	board.started = true
	return board


func _free(board: HexBoard) -> void:
	remove_child(board)
	board.free()


## One measure: the four beats, in Level.gd's order.
func _measure(board: HexBoard) -> void:
	board.resolve_placement_phase()
	board.resolve_water_phase()
	board.resolve_terrain_phase()
	board.resolve_status_phase()


## The water_cells entry at `coord`, or {} if the cell is dry.
func _water_at(board: HexBoard, coord: Vector2i) -> Dictionary:
	for entry in board.water_cells:
		if entry["coord"] == coord:
			return entry
	return {}


## A single drop, placed by hand one cell up-right of `target` and heading
## DOWN_LEFT, so it moves into `target` on the next WATER beat.
func _drop_into(board: HexBoard, target: Vector2i) -> void:
	board.water_cells.append({"coord": target - Hex.DOWN_LEFT, "next_dir": Hex.DOWN_LEFT})


# --- the timing rule ---------------------------------------------------------

func _check_timing() -> void:
	for d in [1, 2, 3, 5]:
		print("Timing: one drop through a tunnel of length %d" % d)
		var entrance := Vector2i(0, -4)
		var exit_cell := entrance + Vector2i(d, 0) # a straight run of d cells
		var board := _board(_data({entrance: exit_cell}))
		_check(board._cube_distance(exit_cell - entrance) == d, "the two ends are %d apart (precondition)" % d)
		_drop_into(board, entrance)

		_measure(board) # WATER beat 1: the drop reaches the mouth
		_check(board.water_beat == 1, "water_beat counts the WATER beat")
		_check(board.water_cells.is_empty(), "t: the drop is off the surface the beat it goes in")
		_check(_water_at(board, entrance).is_empty(), "t: it is not drawn sitting on the entrance")
		_check(board.tunnel_transit.size() == 1, "t: it is in flight underground")
		if board.tunnel_transit.size() == 1:
			var transit: Dictionary = board.tunnel_transit[0]
			_check(transit["entrance"] == entrance and transit["exit"] == exit_cell,
				"t: in flight from this entrance to this exit")
			_check(transit["entered"] == 1 and transit["due"] == 1 + d,
				"t: entered on beat 1, due on beat %d (got %d, %d)" % [1 + d, transit["entered"], transit["due"]])

		var early := false
		for beat in range(2, 1 + d): # beats t+1 .. t+d-1: still underground
			_measure(board)
			if not board.water_cells.is_empty() or board.tunnel_transit.size() != 1:
				early = true
		_check(not early, "t+1 .. t+%d: still underground, the surface stays dry" % (d - 1))

		_measure(board) # WATER beat 1 + d
		var surfaced := _water_at(board, exit_cell)
		_check(board.water_cells.size() == 1 and not surfaced.is_empty(),
			"t+%d: the drop is ON the exit, and nowhere else" % d)
		_check(surfaced.get("next_dir", Vector2i.ZERO) == Hex.DOWN_LEFT,
			"t+%d: it will fall DOWN_LEFT first, like a source's stream" % d)
		_check(board.tunnel_transit.is_empty(), "t+%d: nothing is left underground" % d)

		_measure(board) # WATER beat 2 + d
		_check(not _water_at(board, exit_cell + Hex.DOWN_LEFT).is_empty() and board.water_cells.size() == 1,
			"t+%d: it has fallen DOWN_LEFT off the exit" % (d + 1))
		_measure(board)
		_check(not _water_at(board, exit_cell + Hex.DOWN_LEFT + Hex.DOWN_RIGHT).is_empty(),
			"t+%d: then DOWN_RIGHT -- the ordinary zigzag" % (d + 2))
		_free(board)


func _check_continuous_stream() -> void:
	print("A continuous stream keeps emerging every beat")
	var source := Vector2i(1, -5)
	var entrance := source + Hex.DOWN_LEFT # the source's very first move
	var d := 3
	var exit_cell := entrance + Vector2i(d, 0)
	var board := _board(_data({entrance: exit_cell}, [source]))
	var wet_every_beat := true
	var steady_transit := true
	for beat in range(1, 1 + d + 8):
		_measure(board)
		if beat >= 1 + d and _water_at(board, exit_cell).is_empty():
			wet_every_beat = false
		if beat >= d and board.tunnel_transit.size() != d:
			steady_transit = false
		if not _water_at(board, entrance).is_empty():
			wet_every_beat = false
	_check(wet_every_beat, "the exit is wet on every beat from t+d on, the entrance never")
	_check(steady_transit, "exactly d = %d drops are in flight at once, one per underground cell" % d)
	_free(board)


func _check_diverter_and_splitter() -> void:
	var source := Vector2i(2, -6)
	var landing := source + Hex.DOWN_LEFT # where the source's first drop lands
	var entrance := landing + Hex.DOWN_LEFT # a Diverter-Left's target from there
	var exit_cell := entrance + Vector2i(3, -1)
	var tunnels := {entrance: exit_cell}

	print("Natural fall from the landing cell misses the mouth (precondition)")
	var board := _board(_data(tunnels, [source]))
	_measure(board)
	_measure(board)
	_check(not _water_at(board, landing + Hex.DOWN_RIGHT).is_empty() and board.tunnel_transit.is_empty(),
		"without a block the stream zigzags DOWN_RIGHT past the entrance")
	_free(board)

	print("A Diverter redirect into the entrance")
	var data := _data(tunnels, [source], {"divert_left": 1})
	board = HexBoard.new()
	add_child(board)
	board.setup(data, _catalog)
	_check(board.place_block(landing, "divert_left"), "a Diverter-Left goes down above the mouth")
	board.started = true
	_measure(board)
	_measure(board)
	_check(board.tunnel_transit.size() == 1 and board.tunnel_transit[0]["entered"] == 2,
		"the redirected drop goes underground on beat 2")
	_check(_water_at(board, entrance).is_empty(), "and is not left standing on the entrance")
	for i in range(3):
		_measure(board)
	_check(not _water_at(board, exit_cell).is_empty(), "it surfaces on the exit at beat 2 + d = 5")
	_free(board)

	print("A Splitter branch into the entrance")
	data = _data(tunnels, [source], {"splitter": 1})
	board = HexBoard.new()
	add_child(board)
	board.setup(data, _catalog)
	_check(board.place_block(landing, "splitter"), "a Splitter goes down above the mouth")
	board.started = true
	_measure(board)
	_measure(board)
	_check(board.tunnel_transit.size() == 1, "the DOWN_LEFT branch goes underground")
	_check(not _water_at(board, landing + Hex.DOWN_RIGHT).is_empty(),
		"the DOWN_RIGHT branch carries on along the surface")
	_free(board)


func _check_exit_parking() -> void:
	print("The exit parks when both its fall cells are walled")
	var entrance := Vector2i(0, -4)
	var exit_cell := Vector2i(3, -4)
	var board := HexBoard.new()
	add_child(board)
	board.setup(_data({entrance: exit_cell}, [], {"wall": 1}), _catalog)
	# One Wall anchored on the exit's DOWN_LEFT cell also covers its
	# DOWN_RIGHT cell -- the Wall is two tiles wide.
	_check(board.place_block(exit_cell + Hex.DOWN_LEFT, "wall"), "a Wall goes down under the exit")
	_check(board.placed_blocks.has(exit_cell + Hex.DOWN_LEFT) and board.placed_blocks.has(exit_cell + Hex.DOWN_RIGHT),
		"covering both of its fall cells (precondition)")
	board.started = true
	_drop_into(board, entrance)
	for i in range(4): # surfaces at the end of beat 4
		_measure(board)
	_check(not _water_at(board, exit_cell).is_empty(), "the drop surfaces on the exit")
	var parked := true
	for i in range(4):
		_measure(board)
		if board.water_cells.size() != 1 or _water_at(board, exit_cell).is_empty():
			parked = false
	_check(parked, "and stays there, one drop, four beats later")
	_check(not board.game_over, "parking is not a loss")
	_free(board)


func _check_blocks_refused() -> void:
	print("Blocks are refused on both ends")
	var entrance := Vector2i(0, -2)
	var exit_cell := Vector2i(0, 2)
	var inventory := {"wall": 2, "divert_left": 2, "divert_right": 1, "splitter": 1}
	var board := HexBoard.new()
	add_child(board)
	board.setup(_data({entrance: exit_cell}, [], inventory), _catalog)
	for id in ["divert_left", "divert_right", "splitter", "wall"]:
		_check(not board.place_block(entrance, id), "no %s on the entrance" % id)
		_check(not board.place_block(exit_cell, id), "no %s on the exit" % id)
	_check(board.inventory == inventory, "a refused placement costs nothing")
	# A Wall whose right-hand half would land on a tunnel end mirrors left
	# instead, like against any other terrain.
	_check(board.place_block(entrance - Vector2i(1, 0), "wall"), "a Wall beside the entrance still goes down")
	_check(not board.placed_blocks.has(entrance), "mirrored away from it, not over it")
	_check(board.place_block(exit_cell - Vector2i(1, 0), "wall"), "same beside the exit")
	_check(not board.placed_blocks.has(exit_cell), "mirrored away from it too")
	_check(board.cell_terrain.get(entrance) == HexBoard.CellState.TUNNEL_IN
		and board.cell_terrain.get(exit_cell) == HexBoard.CellState.TUNNEL_OUT,
		"setup() marks the entrance TUNNEL_IN and the exit TUNNEL_OUT")
	_check(not board._is_wall(entrance) and not board._is_wall(exit_cell)
		and not board._is_solid_block(entrance) and not board._is_solid_block(exit_cell),
		"neither end is solid to water")
	_free(board)


func _check_two_tunnels() -> void:
	print("Two tunnels with different delays, side by side")
	var e1 := Vector2i(-3, -4)
	var x1 := e1 + Vector2i(0, 2) # d = 2
	var e2 := Vector2i(1, -4)
	var x2 := e2 + Vector2i(4, 0) # d = 4
	var board := _board(_data({e1: x1, e2: x2}))
	_drop_into(board, e1)
	_drop_into(board, e2)
	_measure(board)
	_check(board.water_cells.is_empty() and board.tunnel_transit.size() == 2, "both drops go under on beat 1")
	_measure(board)
	_measure(board) # beat 3 = 1 + 2
	_check(not _water_at(board, x1).is_empty(), "the short tunnel's drop is out on beat 3")
	_check(_water_at(board, x2).is_empty() and board.tunnel_transit.size() == 1,
		"the long tunnel's is still underground")
	_measure(board)
	_check(_water_at(board, x2).is_empty(), "and still on beat 4")
	_measure(board) # beat 5 = 1 + 4
	_check(not _water_at(board, x2).is_empty() and board.tunnel_transit.is_empty(),
		"the long tunnel's drop is out on beat 5")
	_free(board)


func _check_flat_grid() -> void:
	print("Flat grid: a straight source into a tunnel, straight out of the exit")
	var source := Vector2i(0, -5)
	var entrance := source + Hex.FLAT_DOWN
	var d := 3
	var exit_cell := entrance + Vector2i(d, -1) # cube distance 3, up and to the right
	var board := _board(_data({entrance: exit_cell}, [source], {}, true))
	_check(board._cube_distance(exit_cell - entrance) == d, "the two ends are %d apart (precondition)" % d)
	_measure(board)
	_check(board.tunnel_transit.size() == 1 and board.tunnel_transit[0]["due"] == 1 + d,
		"the straight stream goes under on beat 1, due on beat %d" % (1 + d))
	_check(_water_at(board, entrance).is_empty(), "and is not left on the entrance")
	for i in range(d):
		_measure(board)
	var surfaced := _water_at(board, exit_cell)
	_check(surfaced.get("next_dir", Vector2i.ZERO) == Hex.FLAT_DOWN and surfaced.get("mode", "") == "straight",
		"t+d: on the exit, set to fall straight down")
	_measure(board)
	_check(not _water_at(board, exit_cell + Hex.FLAT_DOWN).is_empty(), "t+d+1: straight down off the exit")
	_measure(board)
	_check(not _water_at(board, exit_cell + Hex.FLAT_DOWN * 2).is_empty(), "t+d+2: and straight on down")
	_free(board)

	print("Flat grid: a Diverter redirect into the entrance")
	var landing := source + Hex.FLAT_DOWN
	var mouth := landing + Hex.FLAT_DOWN_LEFT
	var data := _data({mouth: mouth + Vector2i(2, -1)}, [source], {"divert_left": 1}, true)
	board = HexBoard.new()
	add_child(board)
	board.setup(data, _catalog)
	_check(board.place_block(landing, "divert_left"), "a Diverter-Left goes down under the source")
	board.started = true
	_measure(board)
	_measure(board)
	_check(board.tunnel_transit.size() == 1 and board.tunnel_transit[0]["entered"] == 2,
		"the redirected drop goes underground on beat 2")
	_free(board)
	Hex.orientation = Hex.Orientation.POINTY


func _check_preview() -> void:
	print("The pre-Start flow preview crosses a tunnel")
	var source := Vector2i(1, -6)
	var entrance := source + Hex.DOWN_LEFT
	var exit_cell := entrance + Vector2i(3, 0)
	var board := HexBoard.new()
	add_child(board)
	board.setup(_data({entrance: exit_cell}, [source]), _catalog)
	var arrows: Array = board._predict_flow_arrows()
	var into_mouth := false
	var from_mouth := false
	var out_of_exit := false
	for a in arrows:
		if a["from"] == source and a["to"] == entrance: into_mouth = true
		if a["from"] == entrance: from_mouth = true
		if a["from"] == exit_cell and a["to"] == exit_cell + Hex.DOWN_LEFT: out_of_exit = true
	_check(into_mouth, "an arrow goes into the entrance")
	_check(not from_mouth, "none leaves the entrance on the surface")
	_check(out_of_exit, "the branch carries on from the exit, DOWN_LEFT first")
	_check(arrows.size() >= 3, "and keeps going after that (%d arrows)" % arrows.size())
	_check(not board._predict_would_consume(entrance), "the entrance does not read as consuming the branch")
	_free(board)


func _check_exit_arrow() -> void:
	print("The exit's pre-Start arrow points where the spring will really go")
	var entrance := Vector2i(0, -4)
	var exit_cell := Vector2i(3, -4)
	var board := HexBoard.new()
	add_child(board)
	board.setup(_data({entrance: exit_cell}, [], {"wall": 1}), _catalog)
	_check(board._tunnel_exit_first_move(exit_cell) == Hex.DOWN_LEFT, "open ground: DOWN_LEFT, the spring's first try")
	# A Wall on the DOWN_LEFT cell alone, as tunnel_3's solution sets it.
	board.placed_blocks[exit_cell + Hex.DOWN_LEFT] = "wall"
	_check(board._tunnel_exit_first_move(exit_cell) == Hex.DOWN_RIGHT, "a Wall on DOWN_LEFT turns it DOWN_RIGHT")
	board.placed_blocks[exit_cell + Hex.DOWN_RIGHT] = "wall"
	_check(board._tunnel_exit_first_move(exit_cell) == Vector2i.ZERO, "both fall cells walled: no arrow (it parks)")
	_check(board._tunnel_exit_arrow_vector(exit_cell) == Vector2.ZERO, "and so no arrow is drawn")
	board.placed_blocks.clear()
	board.show_flow_preview = true
	_check(board._tunnel_exit_arrow_vector(exit_cell) != Vector2.ZERO, "pre-Start the exit draws its arrow")
	board.show_flow_preview = false
	_check(board._tunnel_exit_arrow_vector(exit_cell) == Vector2.ZERO, "after Start it does not")
	_free(board)

	var low_exit := Vector2i(-4, 8) # on the bottom row of a radius-8 board
	board = HexBoard.new()
	add_child(board)
	board.setup(_data({entrance: low_exit}), _catalog)
	_check(board._tunnel_exit_first_move(low_exit) == Hex.DOWN_LEFT, "on the bottom row: DOWN_LEFT, off the edge")
	_free(board)

	board = HexBoard.new()
	add_child(board)
	board.setup(_data({Vector2i(0, -5): Vector2i(0, -2)}, [], {}, true), _catalog)
	_check(board._tunnel_exit_first_move(Vector2i(0, -2)) == Hex.FLAT_DOWN, "flat grid: straight down")
	_free(board)

	var data: LevelData = load("res://data/sandbox/tunnel_3.tres")
	var exit3: Vector2i = data.tunnel_pairs.values()[0]
	board = HexBoard.new()
	add_child(board)
	board.setup(data.duplicate(true), _catalog)
	_check(board._tunnel_exit_first_move(exit3) == Hex.DOWN_LEFT, "tunnel_3 before the Wall: down-left, toward the town")
	_check(board.place_block(Vector2i(-1, 2), "wall"), "tunnel_3's Wall goes down at (-1, 2)")
	_check(board._tunnel_exit_first_move(exit3) == Hex.DOWN_RIGHT, "tunnel_3 after the Wall: down-right, into the lake")
	_free(board)


func _check_stones() -> void:
	print("One stepping stone per underground beat, lit while a drop is there")
	var entrance := Vector2i(0, -4)
	var exit_cell := Vector2i(4, -4) # d = 4: three stones
	var board := _board(_data({entrance: exit_cell}))
	var stones := board._tunnel_stones(entrance, exit_cell)
	_check(stones.size() == 3, "d = 4 draws 3 stones (got %d)" % stones.size())
	var toward_exit := (Hex.axial_to_pixel(exit_cell) - Hex.axial_to_pixel(entrance)).normalized()
	var chevrons_ok := true
	for stone in stones:
		if (stone["dir"] as Vector2).dot(toward_exit) < 0.999:
			chevrons_ok = false
	_check(chevrons_ok, "every stone's chevron points entrance-to-exit, the way the water runs")
	_drop_into(board, entrance)
	var lit_ok := true
	for beat in range(1, 4):
		_measure(board)
		stones = board._tunnel_stones(entrance, exit_cell)
		for i in stones.size():
			# After the WATER beat that is `beat` beats after entry (entry
			# was beat 1), step beat - 1 is lit; step 0 is the mouth.
			if stones[i]["lit"] != (i + 1 == beat - 1):
				lit_ok = false
	_check(lit_ok, "exactly the stone at the drop's step is lit, beat by beat")
	_free(board)


func _check_retry_resets() -> void:
	print("setup() resets the tunnel clock (a Retry)")
	var source := Vector2i(1, -5)
	var entrance := source + Hex.DOWN_LEFT
	var data := _data({entrance: entrance + Vector2i(4, 0)}, [source])
	var board := _board(data)
	for i in range(6):
		_measure(board)
	_check(board.water_beat == 6 and not board.tunnel_transit.is_empty(), "mid-run: beats counted, drops in flight (precondition)")
	board.setup(data, _catalog)
	_check(board.water_beat == 0, "water_beat back to 0")
	_check(board.tunnel_transit.is_empty(), "nothing left underground")
	_check(board._tunnel_exits_opened.is_empty(), "every exit forgotten, so its first gush sounds again")
	board.started = true
	_measure(board)
	_check(board.tunnel_transit.size() == 1 and board.tunnel_transit[0]["entered"] == 1,
		"the next run starts from beat 1 again")
	_free(board)


func _check_event() -> void:
	print("EVENT_TUNNEL: once per exit, on the STATUS beat")
	var source := Vector2i(1, -6)
	var e1 := source + Hex.DOWN_LEFT
	var shared_exit := e1 + Vector2i(3, 0)
	var source2 := Vector2i(-3, -5)
	var e2 := source2 + Hex.DOWN_LEFT # a second mouth onto the same exit
	var source3 := Vector2i(-6, -1)
	var e3 := source3 + Hex.DOWN_LEFT
	var other_exit := e3 + Vector2i(2, 0)
	var board := _board(_data({e1: shared_exit, e2: shared_exit, e3: other_exit}, [source, source2, source3]))
	var heard: Array = []
	board.board_event.connect(func(kind: StringName, coord: Vector2i): if kind == HexBoard.EVENT_TUNNEL: heard.append(coord))
	for i in range(10):
		_measure(board)
	_check(heard.count(shared_exit) == 1, "the shared exit sounds once, however many mouths feed it (%d)" % heard.count(shared_exit))
	_check(heard.count(other_exit) == 1, "the other exit sounds once too (%d)" % heard.count(other_exit))
	_check(heard.size() == 2, "two exits, two events in 10 beats of continuous flow (%d)" % heard.size())
	_free(board)

	board = _board(_data({e1: shared_exit}, [source]))
	var count := [0]
	board.board_event.connect(func(kind: StringName, _coord: Vector2i): if kind == HexBoard.EVENT_TUNNEL: count[0] += 1)
	for i in range(3):
		_measure(board)
	board.resolve_placement_phase()
	board.resolve_water_phase() # beat 4 = 1 + 3: the first drop surfaces
	board.resolve_terrain_phase()
	_check(count[0] == 0, "not yet on the WATER or TERRAIN beat it surfaces on")
	board.resolve_status_phase()
	_check(count[0] == 1, "revealed on that measure's STATUS beat, with the change")
	_free(board)

	var sounds: Dictionary = LEVEL_SCRIPT.BOARD_SOUNDS
	_check(sounds.get(HexBoard.EVENT_TUNNEL, &"") == &"geyser", "Level.BOARD_SOUNDS plays it as the geyser's gush")
	_check(Sfx.SOUNDS.has(&"geyser"), "a sound the catalogue actually has")


func _check_smoke_validation() -> void:
	print("tools/smoke_test.gd rejects a bad tunnel (in memory)")
	var good := _sandbox_like()
	_check(_smoke_errors(good).is_empty(), "a clean pair passes: %s" % str(_smoke_errors(good)))

	# [what, tunnel_pairs, preset_blocks] -- each breaks one rule.
	var probe := _sandbox_like()
	var e := Vector2i(0, -2)
	var cases := [
		["an entrance on a fire", {probe.fire_cells[0]: Vector2i(0, 2)}, {}],
		["an exit on a water source", {e: probe.water_sources[0]}, {}],
		["an exit in a lake", {e: probe.lake_cells.values()[0][0]}, {}],
		["an entrance on a town", {probe.town_cells[0]: Vector2i(0, 2)}, {}],
		["an exit on a blocked cell", {e: probe.blocked_cells[0]}, {}],
		["an exit off the grid", {e: Vector2i(9, 0)}, {}],
		["entrance == exit", {e: e}, {}],
		["a cell both an entrance and an exit", {e: Vector2i(0, 2), Vector2i(0, 2): Vector2i(1, 0)}, {}],
		["an end on a preset Wall's second cell", {e: Vector2i(0, 0)}, {Vector2i(-1, 0): "wall"}],
	]
	for case in cases:
		var lv := _sandbox_like()
		lv.tunnel_pairs = case[1]
		lv.preset_blocks = case[2]
		var errors := _smoke_errors(lv)
		_check(not errors.is_empty(), "rejects %s: %s" % [case[0], str(errors)])

	var shared := _sandbox_like()
	shared.tunnel_pairs = {Vector2i(0, -2): Vector2i(0, 2), Vector2i(1, -2): Vector2i(0, 2)}
	_check(_smoke_errors(shared).is_empty(), "two entrances sharing one exit are allowed")


## A small valid level to break in different ways.
func _sandbox_like() -> LevelData:
	var lv := LevelData.new()
	lv.grid_radius = 4
	var sources: Array[Vector2i] = [Vector2i(1, -4)]
	lv.water_sources = sources
	var fires: Array[Vector2i] = [Vector2i(-1, -1)]
	lv.fire_cells = fires
	var towns: Array[Vector2i] = [Vector2i(2, -1)]
	lv.town_cells = towns
	lv.pool_targets = {Vector2i(-2, 3): 4}
	var lake: Array[Vector2i] = [Vector2i(-2, 4), Vector2i(-1, 3), Vector2i(-1, 4)]
	lv.lake_cells = {Vector2i(-2, 3): lake}
	var blocked: Array[Vector2i] = [Vector2i(3, 0)]
	lv.blocked_cells = blocked
	lv.tunnel_pairs = {Vector2i(0, -2): Vector2i(0, 2)}
	return lv


func _smoke_errors(lv: LevelData) -> Array[String]:
	var errors: Array[String] = []
	SMOKE_TEST._check_tunnels("mem", lv, _catalog, errors)
	return errors


# --- the sandbox levels ------------------------------------------------------

func _check_sandbox_levels() -> void:
	var solutions := _read_sandbox_solutions()
	for i in SANDBOX.size():
		var name: String = SANDBOX[i]
		var path := "res://data/sandbox/%s.tres" % name
		print("Sandbox level %s" % name)
		var data: LevelData = load(path)
		_check(data != null, "%s loads" % path)
		if data == null:
			continue
		_check(data.level_id == 951 + i, "level_id %d" % (951 + i))
		_check(data.display_name.begins_with("Tunnel %d: " % (i + 1)), "named \"%s\"" % data.display_name)
		_check(data.display_name.get_slice(":", 0).strip_edges() == "Tunnel %d" % (i + 1),
			"the HUD shows it as \"Tunnel %d\", short enough to clear Play and Pause" % (i + 1))
		_check(not data.intro_text.is_empty(), "has an intro that teaches the tile")
		_check(not data.tunnel_pairs.is_empty(), "has a tunnel")
		_check(_smoke_errors(data).is_empty(), "its tunnel passes the smoke-test rules")
		_check(_at_most_six_wide(data), "at most 6 hexes wide, rows -4..4 (the rule for levels 1-50)")

		var bare := _play(data, [])
		_check(bare["outcome"] != "win", "the bare run does not win (%s @%d)" % [bare["outcome"], bare["measures"]])

		if not solutions.has(name):
			_check(false, "../sandbox-solutions.md records a solution")
			continue
		var sol: Dictionary = solutions[name]
		var r := _play(data, sol["placements"])
		_check(r["rejected"].is_empty(), "every recorded placement is accepted")
		_check(r["outcome"] == "win" and r["measures"] == sol["measures"],
			"the recorded solution wins in %d measures (got %s @%d)" % [sol["measures"], r["outcome"], r["measures"]])
		_check(r["went_under"] and r["surfaced"], "and water goes through the tunnel on the way")


## Plays a level to its end the way tools/Sim.gd does, noting whether any
## water went underground and whether any came back up.
func _play(data: LevelData, placements: Array) -> Dictionary:
	var board := HexBoard.new()
	add_child(board)
	board.setup(data.duplicate(true), _catalog)
	var state := {"won": false, "lost": false, "surfaced": false}
	board.level_won.connect(func(): state["won"] = true)
	board.level_lost.connect(func(): state["lost"] = true)
	board.board_event.connect(func(kind: StringName, _c: Vector2i): if kind == HexBoard.EVENT_TUNNEL: state["surfaced"] = true)
	var rejected := []
	for p in placements:
		if not board.place_block(p["coord"], p["block"]):
			rejected.append(p)
	board.started = true
	var went_under := false
	var measures := 0
	while measures < 200 and not state["won"] and not state["lost"]:
		board.resolve_placement_phase()
		board.resolve_water_phase()
		if not board.tunnel_transit.is_empty():
			went_under = true
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		measures += 1
	_free(board)
	return {"outcome": "win" if state["won"] else ("loss" if state["lost"] else "timeout"),
		"measures": measures, "went_under": went_under, "surfaced": state["surfaced"],
		"rejected": rejected}


## Every playable cell sits in offset columns -3..2 and rows -4..4 -- the
## 6-wide, 9-row box every level in 1-50 keeps.
func _at_most_six_wide(data: LevelData) -> bool:
	var board := HexBoard.new()
	board.level_data = data
	var ok := true
	var r := data.grid_radius
	for q in range(-r, r + 1):
		for row in range(-r, r + 1):
			var c := Vector2i(q, row)
			if not board.in_playable_area(c):
				continue
			@warning_ignore("integer_division")
			var col: int = q + (row - (row & 1)) / 2
			if col < -3 or col > 2 or absi(row) > 4:
				ok = false
	board.free()
	return ok


## ../sandbox-solutions.md, one line per level in level-solutions.md's
## grammar with the level's file name in place of its number:
##   - **tunnel_1** — divert-left (2, -3) | win 10
func _read_sandbox_solutions() -> Dictionary:
	var path := ProjectSettings.globalize_path("res://").path_join("../sandbox-solutions.md").simplify_path()
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var names := {"wall": "wall", "splitter": "splitter", "divert-right": "divert_right",
		"diverter-right": "divert_right", "divert-left": "divert_left", "diverter-left": "divert_left"}
	var line_re := RegEx.create_from_string("^- \\*\\*([a-z0-9_]+)\\*\\* — (.+?) \\| win (\\d+)\\s*$")
	var placement_re := RegEx.create_from_string("([A-Za-z][A-Za-z-]*)\\s*\\((-?\\d+),\\s*(-?\\d+)\\)")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var m := line_re.search(line)
		if m == null:
			continue
		var placements := []
		for p in placement_re.search_all(m.get_string(2)):
			placements.append({"coord": Vector2i(int(p.get_string(2)), int(p.get_string(3))),
				"block": names.get(p.get_string(1).to_lower(), p.get_string(1))})
		out[m.get_string(1)] = {"placements": placements, "measures": int(m.get_string(3))}
	return out
