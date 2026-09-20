extends Control
class_name LevelMap

## The ground and the winding trail behind the Level Select map. Level
## nodes are added as this Control's children, so they draw ON TOP of what
## this node draws in _draw() -- a Control paints itself before its
## children.
##
## The ground is banded: each ten levels of trail sit on their decade's
## ground colour (Backdrop), faded into the next across the gap between
## the last level of one decade and the first of the next, so scrolling
## the map is the same journey through the same ten backdrops the levels
## make. The bands scroll with the trail because they are drawn here, in
## the content, not on the fixed Grass rect behind the ScrollContainer.
##
## The trail is split at the furthest level the player has reached: the
## stretch they have already travelled is drawn solid and bright, the rest
## dim, so progress reads at a glance while scrolling without needing a
## counter anywhere.

## One point per level, in level order (level 1 first). Set by LevelSelect.
var points: PackedVector2Array = PackedVector2Array()

## Colour stops down the map, top first, as {"y": float, "palette": int}
## -- an index into Backdrop.PALETTES. Between two stops of the same
## palette the ground is solid; between two that differ it fades linearly.
## Set by LevelSelect._build_map(), which knows where the levels are.
var bands: Array[Dictionary] = []

## How many leading points count as "reached" -- the trail up to this many
## levels is drawn bright. 1 means only level 1 has been reached.
var reached_count: int = 1

## Side-path spurs branching off the trail, as
## {"from": Vector2, "to": Vector2, "open": bool}. Drawn in the same pass as
## the trail so a spur reads as part of the route rather than decoration,
## but thinner, and dim until its gate has been met.
var spurs: Array[Dictionary] = []

const TRAIL_WIDTH := 14.0
const TRAIL_CASING_WIDTH := 22.0
const CASING_COLOR := Color(0.16, 0.32, 0.14, 0.55)
const TRAIL_REACHED := Color(0.93, 0.87, 0.66, 0.95) # a worn dirt path
const TRAIL_AHEAD := Color(0.86, 0.86, 0.82, 0.28)
const SPUR_WIDTH := 9.0
const SPUR_CASING_WIDTH := 16.0
const SPUR_OPEN := Color(0.97, 0.82, 0.42, 0.95)   # amber, matching the bonus node
const SPUR_LOCKED := Color(0.86, 0.86, 0.82, 0.22)


func _draw() -> void:
	_draw_bands()
	if points.size() < 2:
		return
	# Casing first, as one pass under the whole trail, so the lighter core
	# drawn over it reads as a single continuous path rather than a row of
	# separately-outlined segments meeting at the joins.
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], CASING_COLOR, TRAIL_CASING_WIDTH, true)
	for i in range(points.size() - 1):
		var reached := (i + 1) < reached_count
		draw_line(points[i], points[i + 1], TRAIL_REACHED if reached else TRAIL_AHEAD, TRAIL_WIDTH, true)

	# Spurs last, so an open one sits over the trail it leaves rather than
	# being buried by it.
	for spur in spurs:
		draw_line(spur["from"], spur["to"], CASING_COLOR, SPUR_CASING_WIDTH, true)
	for spur in spurs:
		draw_line(spur["from"], spur["to"],
			SPUR_OPEN if spur["open"] else SPUR_LOCKED, SPUR_WIDTH, true)


## One quad per pair of neighbouring stops, the full width of the map,
## with the stop colours on its vertices so the renderer does the fade.
## Twenty stops for a hundred levels: the cost is nothing, whatever the
## scroll position.
func _draw_bands() -> void:
	if bands.size() < 2:
		return
	var right: float = size.x
	for i in range(bands.size() - 1):
		var top: float = bands[i]["y"]
		var bottom: float = bands[i + 1]["y"]
		if bottom <= top:
			continue
		var above: Color = Backdrop.PALETTES[bands[i]["palette"]]["ground"]
		var below: Color = Backdrop.PALETTES[bands[i + 1]["palette"]]["ground"]
		draw_polygon(
			PackedVector2Array([Vector2(0.0, top), Vector2(right, top), Vector2(right, bottom), Vector2(0.0, bottom)]),
			PackedColorArray([above, above, below, below]))


## The band colour at content height `y`; `key` is "ground" or "sky".
## Solid inside a band, a linear fade across a boundary -- the same fade
## _draw_bands() paints, so the header's sky and the ground under a chapter
## label both agree with what is drawn. The meadow when no bands are set.
func colour_at(y: float, key: String) -> Color:
	if bands.is_empty():
		return Backdrop.PALETTES[0][key]
	if y <= bands[0]["y"]:
		return Backdrop.PALETTES[bands[0]["palette"]][key]
	for i in range(bands.size() - 1):
		var top: float = bands[i]["y"]
		var bottom: float = bands[i + 1]["y"]
		if y <= bottom:
			var above: Color = Backdrop.PALETTES[bands[i]["palette"]][key]
			var below: Color = Backdrop.PALETTES[bands[i + 1]["palette"]][key]
			if bottom <= top:
				return below
			return above.lerp(below, (y - top) / (bottom - top))
	return Backdrop.PALETTES[bands.back()["palette"]][key]
