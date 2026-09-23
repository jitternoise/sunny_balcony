extends Control
class_name AmbientBackdrop

## The moving half of a backdrop: clouds drifting across the sky, their
## shadows sliding over the ground beneath them, now and then a flock of
## birds, and stars on the one band whose sky is dark enough for them.
## Backdrop.PALETTES says which of these a band has; this draws them.
##
## Sits over the flat Sky and Grass ColorRects and under everything else
## -- the last child of Level.tscn's Background layer, and of MainMenu --
## full-bleed like them. It must never take a tap: on the level screen a
## Control that stopped mouse input here would swallow every press before
## Level._unhandled_input() saw it, so mouse_filter is forced to IGNORE.
##
## Cheap by construction. Each cloud, shadow and bird is its own small
## node, drawn once; animating one is setting its position, which records
## no draw commands. Only the birds' wingbeats and the stars' twinkle
## redraw, at TICK_FPS -- the board's heartbeat rate -- and a bird only
## while it is on screen.
##
## Stops whenever the board does (Level._update_board_animation() sets
## `running`) and whenever the player has switched it off in Options
## (Settings.background_motion). Stopping freezes it where it stands
## rather than clearing it, and the clock only advances while it runs, so
## starting again carries on from the same frame instead of jumping.
##
## Laid out from a fixed seed per band, so a band looks the same on every
## visit and the snapshot harness (Engine.time_scale 0) captures a
## repeatable frame.

## Where the sky ends, as a fraction of the height: the Sky/Grass split
## both scenes author (Sky anchor_bottom, Grass anchor_top).
const HORIZON := 0.2

## The board's animation heartbeat (HexBoard.ANIM_TICK_FPS), repeated here
## rather than named so the main menu does not load the board's script.
## VerifyAmbience holds the two together.
const TICK_FPS := 12.0

## How far past either edge something drifts before it wraps round to the
## other side. Wider than the widest shadow, so nothing pops in or out.
const MARGIN := 240.0

## Clouds come in two depths. FAR ones are smaller, slower and closer to
## the sky's own colour; NEAR ones are larger, faster, nearer the band's
## cloud tint, and cast the shadows. Speeds are px/s, left to right.
const FAR_WIDTH := Vector2(70.0, 110.0)
const NEAR_WIDTH := Vector2(120.0, 180.0)
const FAR_SPEED := Vector2(4.0, 7.0)
const NEAR_SPEED := Vector2(9.0, 14.0)
const FAR_STRENGTH := 0.55
const NEAR_STRENGTH := 0.92
## A cloud's underside: its own colour pulled this far back toward the sky,
## showing as a band this many px deep along the bottom.
const UNDERSIDE_STRENGTH := 0.3
const UNDERSIDE_DROP := 4.0
## The gap kept between a cloud and the horizon, and the top of the screen.
const SKY_PAD := 12.0

## A near cloud's shadow is a soft ellipse this much wider than the cloud,
## and this tall for its width.
const SHADOW_WIDTH := 1.6
const SHADOW_ASPECT := 0.45
const SHADOW_TEXTURE_SIZE := 64

## A flock crosses right to left once every FLOCK_PERIOD seconds, the first
## FLOCK_FIRST seconds in, and is off screen the rest of the time.
const FLOCK_PERIOD := 40.0
const FLOCK_FIRST := 3.0
const FLOCK_SPEED := 42.0
const FLOCK_SIZE := Vector2i(3, 5)
const FLOCK_SPREAD := Vector2(70.0, 18.0)
const FLOCK_BOB := 6.0
const BIRD_SPAN := Vector2(6.0, 8.0)
const BIRD_ALPHA := 0.75
const FLAP_HZ := 2.0

const STAR_COUNT := 26
const STAR_COLOR := Color(1.0, 0.96, 0.82)
const STAR_RADIUS := Vector2(1.0, 1.8)
const STAR_RATE := Vector2(0.15, 0.5)

## Which band this is (Backdrop.PALETTES). The main menu keeps the default,
## the meadow; a level sets its own through setup().
@export var band: int = 0

## False while the board is covered or paused; see the header.
var running: bool = true:
	set(value):
		if running == value:
			return
		running = value
		_sync_processing()

## Seconds of motion so far. Only advances while processing.
var _time: float = 0.0
var _tick: int = 0
## The band the current layout was built for; -1 before the first build.
var _built_band: int = -1

## One entry per drifting cloud: {node, x0, speed}, plus its shadow if it
## casts one.
var _clouds: Array[Dictionary] = []
var _birds: Array[Bird] = []
var _flock_y: float = 0.0
var _stars: Stars = null

static var _shadow_texture: GradientTexture2D = null


## One cloud: a flat-bottomed capsule with two or three puffs on top,
## drawn in its underside colour first and then again, UNDERSIDE_DROP px
## higher, in its own. The origin is the middle of the flat base.
class Cloud extends Node2D:
	var width: float = 100.0
	var base_height: float = 20.0
	var puffs: Array[Vector3] = [] # x, y, radius
	var body: Color = Color.WHITE
	var underside: Color = Color.WHITE

	func height() -> float:
		var top := -base_height
		for p in puffs:
			top = minf(top, p.y - p.z)
		return -top

	func _draw() -> void:
		for layer in [[underside, 0.0], [body, -UNDERSIDE_DROP]]:
			var color: Color = layer[0]
			var dy: float = layer[1]
			var r := base_height * 0.5
			draw_rect(Rect2(-width * 0.5 + r, -base_height + dy, width - base_height, base_height), color)
			draw_circle(Vector2(-width * 0.5 + r, -r + dy), r, color, true, -1.0, true)
			draw_circle(Vector2(width * 0.5 - r, -r + dy), r, color, true, -1.0, true)
			for p in puffs:
				draw_circle(Vector2(p.x, p.y + dy), p.z, color, true, -1.0, true)


## One bird: two bent wings, beat set by the owner (-1 down .. +1 up). At
## mid-beat it is the gull's shallow 'm'.
class Bird extends Node2D:
	var span: float = 7.0
	var phase: float = 0.0
	var color: Color = Color.BLACK
	var beat: float = 0.0
	## Where it flies relative to the flock's leader.
	var offset: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var elbow := Vector2(span * 0.5, -span * (0.25 + 0.3 * beat))
		var tip := Vector2(span, -span * 0.6 * beat)
		draw_polyline(PackedVector2Array([
			Vector2(-tip.x, tip.y), Vector2(-elbow.x, elbow.y), Vector2.ZERO, elbow, tip,
		]), color, 2.0, true)


## Every star in one node; the twinkle is each star's alpha, redrawn per
## tick from the shared clock.
class Stars extends Node2D:
	var points: Array[Vector3] = [] # x, y, radius
	var phases: PackedFloat32Array = PackedFloat32Array()
	var rates: PackedFloat32Array = PackedFloat32Array()
	var time: float = 0.0

	func _draw() -> void:
		for i in range(points.size()):
			var p := points[i]
			var glow := 0.35 + 0.65 * (0.5 + 0.5 * sin(TAU * (rates[i] * time + phases[i])))
			draw_circle(Vector2(p.x, p.y), p.z, Color(STAR_COLOR, glow), true, -1.0, true)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_build)
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.background_motion_changed.connect(func(_on: bool): _sync_processing())
	_build()
	_sync_processing()


## Switches to a band's ambience -- a level calls this with
## Backdrop.index_for_level(). Rebuilds only if the band changed.
func setup(band_index: int) -> void:
	if band_index == _built_band:
		return
	band = band_index
	_build()


func sky_height() -> float:
	return size.y * HORIZON


func _sync_processing() -> void:
	var settings := get_node_or_null("/root/Settings") if is_inside_tree() else null
	var allowed: bool = settings == null or settings.background_motion
	set_process(running and allowed)


func _process(delta: float) -> void:
	_time += delta
	_place()


## Rebuilds every drifting thing for the current band and size, from the
## band's seed. Called on setup() and on a resize; the clock is kept, so a
## rebuild lands on the same moment of the same drift.
func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_clouds.clear()
	_birds.clear()
	_stars = null
	_built_band = -1
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_built_band = band

	var palette: Dictionary = Backdrop.PALETTES[clampi(band, 0, Backdrop.PALETTES.size() - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (band + 1)
	var sky: Color = palette["sky"]
	var tint: Color = palette["cloud"]
	var outline := Backdrop.outline_for(palette["ground"])

	# Built back to front: shadows lie on the ground under everything,
	# stars are furthest away, far clouds, then the birds, then near clouds.
	var count: int = palette["clouds"]
	@warning_ignore("integer_division")
	var far := count / 2
	var specs: Array[Dictionary] = []
	for i in range(count):
		var near := i >= far
		# Each depth is spread evenly round the loop, then jittered by up to
		# half a gap, so the sky never opens with its clouds in one clump.
		var slot := i - far if near else i
		var slots := count - far if near else far
		specs.append({
			"near": near,
			"width": rng.randf_range(NEAR_WIDTH.x, NEAR_WIDTH.y) if near else rng.randf_range(FAR_WIDTH.x, FAR_WIDTH.y),
			"speed": rng.randf_range(NEAR_SPEED.x, NEAR_SPEED.y) if near else rng.randf_range(FAR_SPEED.x, FAR_SPEED.y),
			"x0": (float(slot) + rng.randf_range(0.0, 0.5)) / float(slots) * (size.x + 2.0 * MARGIN) - MARGIN,
			"seed": rng.randi(),
		})

	var shadow_alpha: float = palette["shadow"]
	for spec in specs:
		if spec["near"] and shadow_alpha > 0.0:
			var shadow := Sprite2D.new()
			shadow.texture = _shadow()
			shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			shadow.modulate = Color(outline, shadow_alpha)
			var extent := Vector2(spec["width"] * SHADOW_WIDTH, spec["width"] * SHADOW_WIDTH * SHADOW_ASPECT)
			shadow.scale = extent / float(SHADOW_TEXTURE_SIZE)
			var top := sky_height() + extent.y * 0.5
			shadow.position.y = rng.randf_range(top, maxf(top, size.y - extent.y * 0.5))
			add_child(shadow)
			spec["shadow"] = shadow

	if palette["stars"]:
		_stars = Stars.new()
		for i in range(STAR_COUNT):
			_stars.points.append(Vector3(rng.randf_range(0.0, size.x),
				rng.randf_range(SKY_PAD, sky_height() - SKY_PAD),
				rng.randf_range(STAR_RADIUS.x, STAR_RADIUS.y)))
			_stars.phases.append(rng.randf())
			_stars.rates.append(rng.randf_range(STAR_RATE.x, STAR_RATE.y))
		add_child(_stars)

	for spec in specs:
		if not spec["near"]:
			_add_cloud(spec, sky, tint)

	if palette["birds"]:
		_flock_y = rng.randf_range(sky_height() * 0.3, sky_height() - SKY_PAD - FLOCK_SPREAD.y - FLOCK_BOB)
		var n := rng.randi_range(FLOCK_SIZE.x, FLOCK_SIZE.y)
		for i in range(n):
			var bird := Bird.new()
			bird.span = rng.randf_range(BIRD_SPAN.x, BIRD_SPAN.y)
			bird.phase = rng.randf()
			bird.color = Color(outline, BIRD_ALPHA)
			# The leader first; the rest trail behind it and to either side.
			if i > 0:
				bird.offset = Vector2(rng.randf_range(12.0, FLOCK_SPREAD.x), rng.randf_range(-FLOCK_SPREAD.y, FLOCK_SPREAD.y))
			add_child(bird)
			_birds.append(bird)

	for spec in specs:
		if spec["near"]:
			_add_cloud(spec, sky, tint)

	_tick = -1
	_place()


func _add_cloud(spec: Dictionary, sky: Color, tint: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = spec["seed"]
	var cloud := Cloud.new()
	var w: float = spec["width"]
	cloud.width = w
	cloud.base_height = w * 0.2
	var n := rng.randi_range(2, 3)
	for i in range(n):
		var along := -0.22 + 0.44 * (float(i) / float(n - 1)) # -0.22w .. +0.22w
		# The middle puff of three is the tallest.
		var r := w * rng.randf_range(0.14, 0.2) * (1.15 if n == 3 and i == 1 else 1.0)
		var x := w * (along + rng.randf_range(-0.03, 0.03))
		cloud.puffs.append(Vector3(x, -cloud.base_height - r * 0.35, r))
	var strength := NEAR_STRENGTH if spec["near"] else FAR_STRENGTH
	cloud.body = sky.lerp(tint, strength)
	cloud.underside = cloud.body.lerp(sky, UNDERSIDE_STRENGTH)
	var low := cloud.height() + UNDERSIDE_DROP + SKY_PAD
	cloud.position.y = rng.randf_range(low, maxf(low, sky_height() - SKY_PAD))
	add_child(cloud)
	spec["node"] = cloud
	_clouds.append(spec)


## Puts everything where the clock says, and redraws the wingbeats and the
## twinkle when the clock crosses a tick.
func _place() -> void:
	for spec in _clouds:
		var x := wrapf(spec["x0"] + spec["speed"] * _time, -MARGIN, size.x + MARGIN)
		(spec["node"] as Node2D).position.x = x
		if spec.has("shadow"):
			(spec["shadow"] as Node2D).position.x = x
	var tick := int(_time * TICK_FPS)
	var new_tick := tick != _tick
	_tick = tick

	if not _birds.is_empty():
		var lead_x := size.x + FLOCK_SPREAD.x - FLOCK_SPEED * fposmod(_time - FLOCK_FIRST, FLOCK_PERIOD)
		var bob := FLOCK_BOB * sin(_time * 0.8)
		var tick_time := float(tick) / TICK_FPS
		for bird in _birds:
			bird.position = Vector2(lead_x + bird.offset.x, _flock_y + bird.offset.y + bob)
			var on_screen := bird.position.x > -bird.span and bird.position.x < size.x + bird.span
			bird.visible = on_screen
			if on_screen and new_tick:
				bird.beat = sin(TAU * (FLAP_HZ * tick_time + bird.phase))
				bird.queue_redraw()

	if _stars != null and new_tick:
		_stars.time = float(tick) / TICK_FPS
		_stars.queue_redraw()


## A soft white disc fading to nothing at its rim, shared by every shadow
## and tinted per band through modulate.
static func _shadow() -> GradientTexture2D:
	if _shadow_texture != null:
		return _shadow_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	_shadow_texture = GradientTexture2D.new()
	_shadow_texture.gradient = gradient
	_shadow_texture.width = SHADOW_TEXTURE_SIZE
	_shadow_texture.height = SHADOW_TEXTURE_SIZE
	_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
	_shadow_texture.fill_from = Vector2(0.5, 0.5)
	_shadow_texture.fill_to = Vector2(1.0, 0.5)
	return _shadow_texture
