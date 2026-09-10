extends Control
class_name HexTileIcon

## The inventory bar's tile symbol: the block drawn as the hexagon it will
## actually become on the board, rather than its bare glyph on a round
## button. Same fill colour, same thin dark border, same centred icon, so
## what is in the tray and what lands on the grid read as one thing.
##
## Geometry is computed locally rather than through Hex.axial_to_pixel() /
## Hex.hex_corner(). Those read the SHARED statics Hex.SIZE and
## Hex.orientation, which HexBoard owns and rewrites per level -- the
## comment on Hex.SIZE calls that safe precisely because only one HexBoard
## is ever on screen. Adding a second consumer that had to borrow and
## restore them would make that no longer true, for a hexagon that is six
## lines of trigonometry.

## Fraction of the shortest side the footprint is drawn at, leaving a
## little air inside the button.
const FIT_MARGIN := 0.86

## Glyph size relative to one hex's radius. Matches HexBoard.ICON_SCALE so a
## tile in the tray and the same tile on the board carry the same weight.
const ICON_SCALE := 1.5

## Matches _draw_cell()'s cell border exactly.
const BORDER_COLOR := Color(0, 0, 0, 0.4)
const BORDER_WIDTH := 1.0

## The selected tile's border, in place of the dark one. The buttons carry no
## background any more, so this outline is the ONLY thing saying which block
## a tap will place -- and before it there was nothing at all: the tile
## buttons are plain Buttons, so selecting one changed nothing on screen.
const SELECTED_BORDER_COLOR := Color(1, 1, 1, 0.95)
const SELECTED_BORDER_WIDTH := 3.0

## How far an unavailable tile fades. Out-of-stock used to be shown by the
## theme greying the button's circle; with the circle gone the tile itself
## has to carry it, or a spent block looks identical to an available one.
const UNAVAILABLE_ALPHA := 0.3

## What to draw. Set these, then call refresh().
var block: BlockData = null
var flat: bool = false
var selected: bool = false
var available: bool = true


func refresh() -> void:
	queue_redraw()


## Sets selection/availability in one go, redrawing only if something moved.
func set_state(is_selected: bool, is_available: bool) -> void:
	if selected == is_selected and available == is_available:
		return
	selected = is_selected
	available = is_available
	queue_redraw()


## Every cell this block covers: its anchor plus its footprint. The Wall's
## footprint is what makes it two hexes wide, and drawing that here is the
## point -- the tray is where a player decides what to place, so it is
## where the shape should be legible.
func _cells() -> Array:
	var cells := [Vector2i.ZERO]
	if block != null:
		for offset in block.footprint_offsets:
			cells.append(offset)
	return cells


## Local copy of Hex.axial_to_pixel() at radius 1 -- see the note above.
func _unit_center(coord: Vector2i) -> Vector2:
	var q := float(coord.x)
	var r := float(coord.y)
	if flat:
		return Vector2(1.5 * q, sqrt(3.0) * r + sqrt(3.0) / 2.0 * q)
	return Vector2(sqrt(3.0) * q + sqrt(3.0) / 2.0 * r, 1.5 * r)


## Local copy of Hex.hex_corner() at radius 1.
func _unit_corner(center: Vector2, i: int) -> Vector2:
	var angle_deg := 60.0 * i if flat else 60.0 * i - 30.0
	var rad := deg_to_rad(angle_deg)
	return center + Vector2(cos(rad), sin(rad))


func _draw() -> void:
	if block == null:
		return

	var cells := _cells()

	# Measure the whole footprint at radius 1, then solve for the radius
	# that fits it inside this control -- a 2-wide Wall therefore draws its
	# hexes smaller than a 1-wide Diverter draws its one, which is correct:
	# both occupy the same button.
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for coord in cells:
		var c := _unit_center(coord)
		for i in range(6):
			var p := _unit_corner(c, i)
			min_p = min_p.min(p)
			max_p = max_p.max(p)
	var span := max_p - min_p
	if span.x <= 0.0 or span.y <= 0.0:
		return

	var box := size * FIT_MARGIN
	var radius: float = minf(box.x / span.x, box.y / span.y)
	# Centre the footprint's bounding box in the control.
	var origin := size * 0.5 - (min_p + max_p) * 0.5 * radius

	var fade: float = 1.0 if available else UNAVAILABLE_ALPHA
	var fill := Color(block.color.r, block.color.g, block.color.b, block.color.a * fade)
	var border := SELECTED_BORDER_COLOR if selected else BORDER_COLOR
	border.a *= fade
	var border_width := SELECTED_BORDER_WIDTH if selected else BORDER_WIDTH

	for coord in cells:
		var points := PackedVector2Array()
		for i in range(6):
			points.append(origin + _unit_corner(_unit_center(coord), i) * radius)
		draw_colored_polygon(points, fill)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, border, border_width, true)

	# A glyph on EVERY cell of the footprint, which is what the board does:
	# place_block() writes placed_blocks for each covered cell, and
	# _draw_cell() then draws that block's icon on each. So a 2-wide Wall
	# carries its glyph twice on the grid, and the tray should agree.
	# (Centring one glyph across the pair instead was tried and reads as a
	# single smudged blob straddling the seam.)
	if block.icon != null:
		var glyph := radius * ICON_SCALE
		var tint := Color(1, 1, 1, fade)
		for coord in cells:
			var center := origin + _unit_center(coord) * radius
			draw_texture_rect(block.icon,
				Rect2(center - Vector2(glyph, glyph) * 0.5, Vector2(glyph, glyph)),
				false, tint)
