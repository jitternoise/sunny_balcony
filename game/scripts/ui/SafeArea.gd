extends RefCounted
class_name SafeArea

## The device's safe area: the part of the screen not covered by a notch, a
## camera cutout, a status bar or an on-screen gesture bar. Everything here
## is static -- this is a namespace, not a node.
##
## This mattered nothing while window/stretch/aspect was "keep", because the
## letterbox bars pushed every pixel of the game clear of the screen edges.
## Under "expand" the game is genuinely full-bleed, so anything anchored to
## an edge -- the level HUD's Back button, Level Select's header row, the
## bottom of the board -- can end up under a cutout or behind the gesture
## bar unless it is inset by hand.
##
## Insets are returned as a Vector4 of (left, top, right, bottom), in the
## VIEWPORT's units rather than physical pixels, so they can be added
## straight onto a Control's offsets. DisplayServer reports the safe area in
## screen pixels; under a canvas_items stretch those are not the same thing,
## and _to_viewport_units() does the conversion.


## Test hook. `FLASH_FLOOD_SAFE_INSETS="left,top,right,bottom"` (screen
## pixels) forces an inset on a platform that has none, which is the only
## way to see this code do anything on a desktop: Linux, Windows and macOS
## all report the whole screen as safe. Everything downstream of the parse
## -- the pixels-to-viewport-units conversion, every consumer -- runs
## exactly as it does on a phone. Read from the environment on every call
## rather than cached, so a test can set it with OS.set_environment() and
## have the next layout pass pick it up.
const SIMULATE_ENV := "FLASH_FLOOD_SAFE_INSETS"

## Sanity bound. A safe-area inset covering more than this fraction of the
## window is a bad reading, not a device: it would push the HUD into a
## sliver. Clamped rather than trusted, so a wrong answer from the platform
## degrades into a cramped screen instead of an unusable one.
const MAX_INSET_FRACTION := 0.25


## The current insets in viewport units, as (left, top, right, bottom).
## Vector4.ZERO on desktop and on anything that reports no cutout, which is
## the common case and costs consumers nothing.
static func insets(viewport: Viewport) -> Vector4:
	var raw := _raw_insets_px()
	if raw == Vector4.ZERO:
		return Vector4.ZERO
	return _to_viewport_units(raw, viewport)


## Insets a Control that fills its parent (anchors 0,0,1,1) by `inset`,
## leaving its anchors alone. This is the whole job for the level HUD:
## every button in it is anchored inside this one node, so insetting the
## node moves the lot and the background -- a sibling, on its own
## CanvasLayer -- stays full-bleed behind them.
static func inset_full_rect(control: Control, inset: Vector4) -> void:
	if control == null:
		return
	control.offset_left = inset.x
	control.offset_top = inset.y
	control.offset_right = -inset.z
	control.offset_bottom = -inset.w


## Reads the platform's safe area as (left, top, right, bottom) insets in
## screen pixels, or the simulated one when SIMULATE_ENV is set.
static func _raw_insets_px() -> Vector4:
	var simulated := OS.get_environment(SIMULATE_ENV)
	if simulated != "":
		return _parse_simulated(simulated)

	# Only handhelds have cutouts, and only they report a safe area that is
	# smaller than the screen. Desktops report the whole screen, which
	# would be harmless -- except that a window straddling a screen edge
	# then reads as a genuine inset. Gated rather than clamped.
	if not OS.has_feature("mobile"):
		return Vector4.ZERO

	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO

	var win_pos := DisplayServer.window_get_position()
	var win_size := _window_size()
	if win_size.x <= 0.0 or win_size.y <= 0.0:
		return Vector4.ZERO

	var raw := Vector4(
		float(safe.position.x - win_pos.x),
		float(safe.position.y - win_pos.y),
		float(win_pos.x) + win_size.x - float(safe.position.x + safe.size.x),
		float(win_pos.y) + win_size.y - float(safe.position.y + safe.size.y))
	return _clamp_insets(raw, win_size)


static func _parse_simulated(value: String) -> Vector4:
	var parts := value.split(",", false)
	if parts.size() != 4:
		push_warning("%s must be \"left,top,right,bottom\"; got \"%s\"" % [SIMULATE_ENV, value])
		return Vector4.ZERO
	var raw := Vector4(
		parts[0].to_float(), parts[1].to_float(),
		parts[2].to_float(), parts[3].to_float())
	var win_size := _window_size()
	if win_size.x <= 0.0 or win_size.y <= 0.0:
		return Vector4.ZERO
	return _clamp_insets(raw, win_size)


## Drops negative readings (a window that overhangs a screen edge) and caps
## each inset at MAX_INSET_FRACTION of the window along its own axis.
static func _clamp_insets(raw: Vector4, win_size: Vector2) -> Vector4:
	var max_x := win_size.x * MAX_INSET_FRACTION
	var max_y := win_size.y * MAX_INSET_FRACTION
	return Vector4(
		clampf(raw.x, 0.0, max_x),
		clampf(raw.y, 0.0, max_y),
		clampf(raw.z, 0.0, max_x),
		clampf(raw.w, 0.0, max_y))


## The window's size in screen pixels. Falls back to the root viewport when
## DisplayServer has no window to report -- that is every headless run,
## including the verification suites, where a zero here would silently turn
## every inset into nothing and make the tests pass by measuring air.
static func _window_size() -> Vector2:
	var size := Vector2(DisplayServer.window_get_size())
	if size.x > 0.0 and size.y > 0.0:
		return size
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_visible_rect().size
	return Vector2.ZERO


## Screen pixels -> viewport units. With window/stretch/mode=canvas_items the
## viewport is a scaled copy of the window (720 units across a 1440px phone,
## say), so an inset measured in screen pixels is twice the number of units
## it should move a Control by. Axes are scaled separately even though
## stretch/aspect=expand keeps them equal, because nothing here depends on
## that staying true.
static func _to_viewport_units(raw: Vector4, viewport: Viewport) -> Vector4:
	if viewport == null:
		return raw
	var win_size := _window_size()
	var view_size := viewport.get_visible_rect().size
	if win_size.x <= 0.0 or win_size.y <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return raw
	var scale_x := view_size.x / win_size.x
	var scale_y := view_size.y / win_size.y
	return Vector4(raw.x * scale_x, raw.y * scale_y, raw.z * scale_x, raw.w * scale_y)
