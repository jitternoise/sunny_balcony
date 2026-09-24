extends Node

## Opens one level straight into Level.tscn, skipping the menus and the map.
## For trying a level that is not on the map yet -- the sandbox levels under
## res://data/sandbox/ -- or jumping to any campaign level. From game/:
##
##   LEVEL=tunnel_1 godot --path . --resolution 720x1280 res://tests/PlayLevel.tscn
##
## LEVEL is either a full res:// path or a bare name, looked up as
## res://data/sandbox/<name>.tres and then res://data/levels/<name>.tres
## (so LEVEL=level_042 works too). With no LEVEL, or one that resolves to
## nothing, it prints why and quits with a non-zero code.
##
## Plays on save slot 99, never one of the player's three: a win here
## records progress in slot 99 only (VerifySaveIntegrity keeps to the same
## slot for the same reason). Every level is unlocked for the session.
##
## PLAY_LEVEL_REPORT=1 prints what the level screen shows once it is up --
## the level label, the intro title, the board's size -- and quits, so a
## headless or scripted run can check the launch without a screenshot.

const SLOT := 99
const SEARCH_DIRS: Array[String] = ["res://data/sandbox/", "res://data/levels/"]


## Waits for the Level scene to finish its _ready(), prints what it shows
## and quits. Lives on the root, not in the scene, so it survives the
## change_scene_to_file() that frees PlayLevel itself.
class Reporter extends Node:
	var path := ""
	var _frames := 0

	func _process(_delta: float) -> void:
		_frames += 1
		var level := get_tree().current_scene
		if level == null or level.name != "Level" or _frames < 5:
			return
		var data: LevelData = level.get("level_data")
		var board: HexBoard = level.get_node("Board")
		print("PlayLevel: opened ", path)
		print("PlayLevel: level label   = \"%s\"" % (level.get("level_label") as Label).text)
		print("PlayLevel: intro title   = \"%s\"" % (level.get("intro_title_label") as Label).text)
		print("PlayLevel: level_id %d, %d tunnel(s), slot %d" % [data.level_id, board.level_data.tunnel_pairs.size(), GameState.current_slot])
		get_tree().quit(0)


func _ready() -> void:
	var request := OS.get_environment("LEVEL").strip_edges()
	var path := resolve(request)
	if path == "":
		printerr("PlayLevel: set LEVEL to a res:// path or a level name (e.g. LEVEL=tunnel_1); got \"%s\"" % request)
		get_tree().quit(1)
		return

	GameState.load_slot(SLOT)
	GameState.debug_unlock_all = true
	GameState.pending_level_path = path
	print("PlayLevel: ", path, " on save slot ", SLOT)

	if OS.get_environment("PLAY_LEVEL_REPORT") == "1":
		var reporter := Reporter.new()
		reporter.path = path
		get_tree().root.add_child.call_deferred(reporter)
	get_tree().change_scene_to_file.call_deferred("res://scenes/Level.tscn")


## LEVEL's value -> a loadable level path, or "" if there is none. A bare
## name may carry its .tres or not.
static func resolve(request: String) -> String:
	if request == "":
		return ""
	if request.begins_with("res://"):
		return request if ResourceLoader.exists(request) else ""
	var file_name := request if request.ends_with(".tres") else request + ".tres"
	for dir in SEARCH_DIRS:
		if ResourceLoader.exists(dir + file_name):
			return dir + file_name
	return ""
