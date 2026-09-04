extends RefCounted
class_name Hex

## Static helpers for an axial hex grid, supporting two orientations (see
## `orientation` below): "pointy" (the original grid -- pointed top/bottom
## vertices, no direct down neighbor, water zigzags) and "flat" (rotated
## 90 degrees -- flat top/bottom EDGES, so there IS a direct down neighbor;
## see FLAT_DOWN). Axial coordinates are stored as Vector2i(q, r).

## Hex radius in pixels. Mutable (not a const) because HexBoard.setup()
## rescales it per level so every level's grid fills the same fraction of
## screen width regardless of grid_radius -- see HexBoard._fit_hex_size().
## Safe as a single shared value because only one HexBoard is ever on
## screen at a time (one Level scene, one board).
static var SIZE := 32.0

enum Orientation { POINTY, FLAT }

## Which pixel-math/corner-angle formulas axial_to_pixel()/hex_corner()/
## pixel_to_axial() use. Set once per level by HexBoard.setup() (from
## LevelData.grid_style), same mutable-static pattern as SIZE above and for
## the same reason -- only one HexBoard is ever on screen at a time.
static var orientation: int = Orientation.POINTY

# The two axial neighbors with r+1 on a POINTY grid -- i.e. the two cells
# "below" any given cell (there's no single direct-down neighbor on this
# orientation, since the bottom of a pointy-top hex is a VERTEX, not an
# edge). Used as the default/fork targets for falling water on "pointy"
# levels.
const DOWN_LEFT := Vector2i(-1, 1)
const DOWN_RIGHT := Vector2i(0, 1)

# The three "downward" axial neighbors on a FLAT grid -- this orientation's
# bottom is a flat EDGE, so FLAT_DOWN is a genuine direct-down neighbor
# (the whole point of this grid variant). FLAT_DOWN_LEFT/FLAT_DOWN_RIGHT are
# the true down-left/down-right diagonals, used for this grid's own zigzag
# (see HexBoard._advance_water_flat()) and for Diverter-Left/Diverter-Right
# blocks placed on a "flat" level (see HexBoard._resolve_block_targets()).
# Note FLAT_DOWN_RIGHT does NOT increase r the way the other two do (it's a
# pure q+1 step) -- HexBoard's flat-grid loss detection is written to not
# depend on that, unlike the POINTY grid's bottom-edge shortcut.
const FLAT_DOWN := Vector2i(0, 1)
const FLAT_DOWN_LEFT := Vector2i(-1, 1)
const FLAT_DOWN_RIGHT := Vector2i(1, 0)

const NEIGHBOR_OFFSETS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), DOWN_LEFT, DOWN_RIGHT,
]


static func axial_to_pixel(coord: Vector2i) -> Vector2:
	var q := float(coord.x)
	var r := float(coord.y)
	var x: float
	var y: float
	if orientation == Orientation.FLAT:
		x = SIZE * (3.0 / 2.0 * q)
		y = SIZE * (sqrt(3.0) * r + sqrt(3.0) / 2.0 * q)
	else:
		x = SIZE * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
		y = SIZE * (3.0 / 2.0 * r)
	return Vector2(x, y)


static func pixel_to_axial(pos: Vector2) -> Vector2i:
	var q: float
	var r: float
	if orientation == Orientation.FLAT:
		q = (2.0 / 3.0 * pos.x) / SIZE
		r = (-1.0 / 3.0 * pos.x + sqrt(3.0) / 3.0 * pos.y) / SIZE
	else:
		q = (sqrt(3.0) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / SIZE
		r = (2.0 / 3.0 * pos.y) / SIZE
	return _axial_round(q, r)


static func _axial_round(q: float, r: float) -> Vector2i:
	var x: float = q
	var z: float = r
	var y: float = -x - z
	var rx: float = roundf(x)
	var ry: float = roundf(y)
	var rz: float = roundf(z)
	var x_diff: float = absf(rx - x)
	var y_diff: float = absf(ry - y)
	var z_diff: float = absf(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


static func neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in NEIGHBOR_OFFSETS:
		result.append(coord + offset)
	return result


static func hex_corner(center: Vector2, i: int) -> Vector2:
	# Pointy-top corners sit 30 degrees off the axes (points at top/bottom);
	# flat-top corners sit ON the axes (points at left/right, flat edges at
	# top/bottom) -- this -30 degree offset is the entire difference.
	var angle_deg := 60.0 * i if orientation == Orientation.FLAT else 60.0 * i - 30.0
	var angle_rad := deg_to_rad(angle_deg)
	return center + Vector2(SIZE * cos(angle_rad), SIZE * sin(angle_rad))
