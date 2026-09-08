extends Node
# Autoload singleton (see [autoload] in project.godot).
# Tracks the active save slot and campaign progress, and persists it to disk.
# Also used as a small scratch channel to pass which level to load between
# LevelSelect and Level (see `pending_level_path`).

const SAVE_DIR := "user://saves/"
const SAVE_SLOT_COUNT := 3

var current_slot: int = -1
var highest_unlocked_level: int = 1
var completed_levels: Dictionary = {} # level_id (int) -> true

## Levels whose optional Hydro Plant bonus has been earned -- see
## Level._on_level_won(). Deliberately separate from completed_levels:
## only some levels have a plant at all, finishing one never requires
## switching its plant on, and the bonus is recorded only on a win. A level
## can therefore be completed with the bonus still outstanding, and earning
## it later just adds it here without changing completion.
var hydro_bonus_levels: Dictionary = {} # level_id (int) -> true

## Levels whose par has been met (finished within LevelData.par_measures).
## Only the ten side-path fork levels set a par, and meeting it is what
## opens that level's spur on the Level Select map -- see
## LevelSelect.BONUS_FORKS. Like the hydro bonus this is a record only: it
## never unlocks a main-path level and never affects completion.
var par_levels: Dictionary = {} # level_id (int) -> true

## Debug mode: when true, every level is treated as unlocked regardless of
## save progress (is_level_unlocked() always returns true). Does NOT touch
## highest_unlocked_level or completed_levels, and is never written to a
## save file -- it's a session-only toggle, off by default, and switches
## back off next launch. Defaults on when running from the editor / a
## debug export (OS.is_debug_build()) so developers get it for free; also
## toggleable at runtime from the Level Select screen's "Debug: Unlock All"
## checkbox for testing on a release export.
var debug_unlock_all: bool = OS.is_debug_build()

# Set by LevelSelect before changing scene to Level.tscn; read by Level.gd
# on _ready(). This avoids needing a second autoload just to pass one path.
var pending_level_path: String = ""


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _save_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.save" % slot


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_save_path(slot))


func load_slot(slot: int) -> void:
	current_slot = slot
	highest_unlocked_level = 1
	completed_levels.clear()
	hydro_bonus_levels.clear()
	par_levels.clear()

	if not slot_exists(slot):
		return

	var file := FileAccess.open(_save_path(slot), FileAccess.READ)
	if file == null:
		push_error("Failed to open save slot %d" % slot)
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupt save file in slot %d" % slot)
		return

	highest_unlocked_level = parsed.get("highest_unlocked_level", 1)
	var completed = parsed.get("completed_levels", [])
	completed_levels.clear()
	for level_id in completed:
		completed_levels[int(level_id)] = true
	# Missing in saves written before the bonus existed -- those simply
	# start with no bonuses earned.
	var bonuses = parsed.get("hydro_bonus_levels", [])
	hydro_bonus_levels.clear()
	for level_id in bonuses:
		hydro_bonus_levels[int(level_id)] = true
	var pars = parsed.get("par_levels", [])
	par_levels.clear()
	for level_id in pars:
		par_levels[int(level_id)] = true


func save_current_slot() -> void:
	if current_slot < 0:
		push_error("No active save slot to save to.")
		return

	var data := {
		"highest_unlocked_level": highest_unlocked_level,
		"completed_levels": completed_levels.keys(),
		"hydro_bonus_levels": hydro_bonus_levels.keys(),
		"par_levels": par_levels.keys(),
	}

	var file := FileAccess.open(_save_path(current_slot), FileAccess.WRITE)
	if file == null:
		push_error("Failed to write save slot %d" % current_slot)
		return

	file.store_string(JSON.stringify(data))
	file.close()


func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(_save_path(slot))


func mark_level_complete(level_id: int) -> void:
	completed_levels[level_id] = true
	if level_id + 1 > highest_unlocked_level:
		highest_unlocked_level = level_id + 1
	save_current_slot()


## Records that this level's Hydro Plant bonus has been earned. Never
## unlocks or completes anything on its own -- the bonus is purely a
## record, so a level's progression is identical whether or not it is met.
func mark_hydro_bonus(level_id: int) -> void:
	if hydro_bonus_levels.has(level_id):
		return
	hydro_bonus_levels[level_id] = true
	save_current_slot()


func has_hydro_bonus(level_id: int) -> bool:
	return hydro_bonus_levels.has(level_id)


## Records that this level was finished inside its par. Opens that level's
## side path on the map; changes nothing else.
func mark_par(level_id: int) -> void:
	if par_levels.has(level_id):
		return
	par_levels[level_id] = true
	save_current_slot()


func has_par(level_id: int) -> bool:
	return par_levels.has(level_id)


func is_level_unlocked(level_id: int) -> bool:
	if debug_unlock_all:
		return true
	return level_id <= highest_unlocked_level
