extends Control
class_name LevelMap

## The winding trail behind the Level Select map. Level nodes are added as
## this Control's children, so they draw ON TOP of the path this node draws
## in _draw() -- a Control paints itself before its children.
##
## The trail is split at the furthest level the player has reached: the
## stretch they have already travelled is drawn solid and bright, the rest
## dim, so progress reads at a glance while scrolling without needing a
## counter anywhere.

## One point per level, in level order (level 1 first). Set by LevelSelect.
var points: PackedVector2Array = PackedVector2Array()

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
