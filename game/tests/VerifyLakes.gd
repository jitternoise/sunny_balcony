extends Node

## A pool is four hexes -- a lake -- and the four are ONE target. Checked on
## boards built in code so it does not depend on which cells the level data
## happens to use. Uses no save slot.
##
## The two rules worth guarding:
##  1. Water into any cell of a lake credits the lake's one counter.
##  2. A lake fills by at most one per beat however many of its cells are
##     wet. Without that, a Splitter feeding two cells of one lake would fill
##     it twice as fast and "four beats of connection" would stop meaning
##     anything.

var _checks := 0
var _failures: Array[String] = []
var _catalog: Dictionary


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(what)


func _ready() -> void:
	_catalog = FFSim.load_block_catalog()
	_check_shared_fill()
	_check_one_beat_per_beat()
	_check_cells_behave_as_pool()
	_check_single_cell_still_works()
	print("VerifyLakes: %d checks, %d failed" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	get_tree().quit(1 if _failures.size() > 0 else 0)


## Radius-3 pointy board, source at the top. The natural path from (0,-3)
## is (-1,-2), (-1,-1), (-2,0), (-2,1), (-3,2), (-3,3) -- see the
## tutorial-authoring trace in dev-progress.md.
func _level(anchor: Vector2i, extras: Array, inventory: Dictionary = {}) -> LevelData:
	var d := LevelData.new()
	d.level_id = 999
	d.grid_radius = 3
	var srcs: Array[Vector2i] = [Vector2i(0, -3)]
	d.water_sources = srcs
	d.pool_targets = {anchor: 4}
	var typed: Array[Vector2i] = []
	for e in extras:
		typed.append(e)
	d.lake_cells = {anchor: typed}
	d.starting_inventory = inventory
	return d


func _board(d: LevelData) -> HexBoard:
	var b := HexBoard.new()
	add_child(b)
	b.setup(d, _catalog)
	b.started = true
	return b


func _step(b: HexBoard) -> void:
	b.resolve_placement_phase()
	b.resolve_water_phase()
	b.resolve_terrain_phase()
	b.resolve_status_phase()


func _done(b: HexBoard) -> void:
	remove_child(b)
	b.free()


## The anchor is OFF the natural path; one of its extra cells is on it.
## Water hitting the extra cell must fill the anchor's counter.
func _check_shared_fill() -> void:
	var anchor := Vector2i(-3, 0)                     # off the path
	var d := _level(anchor, [Vector2i(-2, 0), Vector2i(-3, 1), Vector2i(-2, -1)])
	var b := _board(d)
	_check(b.lake_anchor.get(Vector2i(-2, 0)) == anchor, "an extra cell maps to its anchor")
	_check(b.lake_anchor.get(anchor) == anchor, "the anchor maps to itself")
	_check(b.lake_cells_of(anchor).size() == 4, "lake_cells_of() lists all four")
	for m in range(3):
		_step(b)
	_check(b.pool_fill.get(anchor, 0) == 1,
		"water on (-2,0) credits the anchor (-3,0): fill %d" % b.pool_fill.get(anchor, 0))
	_check(not b.pool_fill.has(Vector2i(-2, 0)), "the extra cell has no counter of its own")
	var m := 3
	while m < 20 and not b.game_over:
		_step(b)
		m += 1
	_check(b.game_over and b.lose_reason == "", "the level is won through the extra cell")
	_check(m == 6, "won on measure 6, one fill per beat from first contact (got %d)" % m)
	_done(b)


## A Splitter on the path sends water to (-2,-1) AND (-1,-1) on the same
## beat. Both are cells of one lake. The lake must fill by ONE that beat.
func _check_one_beat_per_beat() -> void:
	var anchor := Vector2i(-2, -1)
	var d := _level(anchor, [Vector2i(-1, -1), Vector2i(-2, 0), Vector2i(-1, 0)],
		{"splitter": 1})
	var b := _board(d)
	b.started = false
	_check(b.place_block(Vector2i(-1, -2), "splitter"), "splitter placed on the path")
	b.started = true
	_step(b) # m1: the first drop lands ON the splitter (two cells below the source)
	_step(b) # m2: both exits land in the lake on the same beat
	_check(b.pool_fill.get(anchor, 0) == 1,
		"two wet cells in one beat credit the lake once (fill %d)" % b.pool_fill.get(anchor, 0))
	var m := 2
	while m < 20 and not b.game_over:
		_step(b)
		m += 1
	_check(b.game_over and b.lose_reason == "", "the split stream still wins")
	# The anchor (-2,-1) is itself on the natural path at m2, so a plain
	# stream would also first touch the lake on m2 and win on m5. The split
	# must not beat that.
	_check(m == 5, "and not any sooner than a single stream would (got %d)" % m)
	_done(b)


## Every cell of a lake is pool terrain: refuses a block, absorbs water,
## draws as pool -- and turns "full" together.
func _check_cells_behave_as_pool() -> void:
	var anchor := Vector2i(-3, 2)
	var extras := [Vector2i(-2, 1), Vector2i(-3, 3), Vector2i(-2, 2)]
	var d := _level(anchor, extras, {"wall": 4, "divert_left": 4})
	var b := _board(d)
	b.started = false
	for cell in extras:
		_check(not b.place_block(cell, "divert_left"), "no block on lake cell %s" % cell)
		_check(b.cell_terrain.get(cell) == HexBoard.CellState.POOL, "%s is pool terrain" % cell)
		_check(b._resolve_tile_state(cell) == b.TILE_POOL, "%s draws as an unfilled pool" % cell)
	b.started = true
	var m := 0
	while m < 20 and not b.game_over:
		_step(b)
		m += 1
	_check(b.game_over and b.lose_reason == "", "lake on the path fills and wins")
	for cell in [anchor] + extras:
		_check(b._resolve_tile_state(cell) == b.TILE_POOL_FULL, "%s draws full once the lake is" % cell)
	_done(b)


## Level data with no lake_cells entry is a one-cell pool -- the engine must
## keep working on any level that predates lakes.
func _check_single_cell_still_works() -> void:
	var d := _level(Vector2i(-3, 3), [])
	d.lake_cells = {}
	var b := _board(d)
	_check(b.lake_cells_of(Vector2i(-3, 3)).size() == 1, "a pool without lake_cells is one cell")
	var m := 0
	while m < 20 and not b.game_over:
		_step(b)
		m += 1
	_check(b.game_over and b.lose_reason == "" and m == 9, "single-cell pool wins on measure 9 as before (got %d)" % m)
	_done(b)
