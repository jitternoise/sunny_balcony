extends SceneTree

## Pixel-compares two directories of board snapshots. Used to prove a
## drawing refactor changed nothing visible:
##   godot --headless --script res://tests/CompareSnapshots.gd -- BEFORE AFTER
##
## Compares the raw RGBA buffers rather than sampling pixel by pixel -- at
## 720x1280 that is a native buffer compare instead of nine million script
## calls per image.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <before_dir> <after_dir>")
		quit(2)
		return
	var before: String = args[0]
	var after: String = args[1]
	var dir := DirAccess.open(before)
	if dir == null:
		printerr("cannot open ", before)
		quit(2)
		return

	var changed := 0
	var checked := 0
	for name in dir.get_files():
		if not name.ends_with(".png"):
			continue
		var a := Image.load_from_file(before.path_join(name))
		var b := Image.load_from_file(after.path_join(name))
		if a == null or b == null:
			printerr("  MISSING  ", name); changed += 1; continue
		checked += 1
		if a.get_size() != b.get_size():
			printerr("  SIZE     %s  %s -> %s" % [name, a.get_size(), b.get_size()])
			changed += 1
			continue
		var da := a.get_data()
		var db := b.get_data()
		if da == db:
			print("  same     %s" % name)
			continue
		# only pay for a detailed count when something actually moved
		var diff_bytes := 0
		var worst := 0
		for i in range(da.size()):
			var d: int = absi(da[i] - db[i])
			if d > 0:
				diff_bytes += 1
				worst = maxi(worst, d)
		printerr("  DIFF     %-16s %d bytes differ (%.3f%% of buffer), worst delta %d"
			% [name, diff_bytes, 100.0 * diff_bytes / da.size(), worst])
		changed += 1
	print("compared %d snapshots; %d changed" % [checked, changed])
	quit(1 if changed > 0 else 0)
