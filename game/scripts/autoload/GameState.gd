extends Node
# Autoload singleton (see [autoload] in project.godot).
# Tracks the active save slot and campaign progress, and persists it to disk.
# Also used as a small scratch channel to pass which level to load between
# LevelSelect and Level (see `pending_level_path`).

const SAVE_DIR := "user://saves/"
const SAVE_SLOT_COUNT := 3

## What is actually on disk for a slot, without loading it -- see
## slot_status(). EMPTY is "no save here, offer a new game"; DAMAGED is
## "something is here and none of it could be read", which is emphatically
## NOT the same thing and must never be presented as one.
enum SlotStatus { EMPTY, OK, DAMAGED }

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

## The tutorial levels live outside the numbered campaign so that adding them
## did not renumber all 100 levels (and invalidate every save, every
## documented solution and every doc that names a level by number). They are
## ordinary LevelData resources with ids in this range, always unlocked, and
## they never move highest_unlocked_level -- see is_level_unlocked() and
## mark_level_complete(). LevelSelect.TUTORIAL_PATHS lists them in order.
const TUTORIAL_ID_FIRST := 901
const TUTORIAL_ID_LAST := 905

## True when the active slot had a save on disk and NONE of it could be read
## -- neither the primary nor its backup. The progress fields are left at
## their new-game defaults, which look exactly like a fresh start, so this
## flag is the only thing that can tell the difference.
##
## While it is set, save_current_slot() refuses to write. That is the whole
## point: the old failure mode was that a damaged save silently presented as
## a new game, and then the player's next win wrote the reset state over the
## top, turning a bad read into permanent data loss. Cleared by load_slot()
## on any slot that reads cleanly, and by discard_damaged_slot().
var load_failed: bool = false

## True when the active slot was recovered from its .bak because the primary
## was missing or unreadable. Progress is intact up to the previous save;
## at most one level of it is gone. Informational -- nothing refuses to
## write in this state, since the backup parsed and is trustworthy.
var loaded_from_backup: bool = false

# Set by LevelSelect before changing scene to Level.tscn; read by Level.gd
# on _ready(). This avoids needing a second autoload just to pass one path.
var pending_level_path: String = ""


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _save_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.save" % slot


## The previous good save, written by save_current_slot() just before it
## replaces the primary. Recovery source when the primary cannot be read.
func _backup_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.save.bak" % slot


## Scratch file a save is built in before being renamed over the primary.
## Never read except to verify it immediately after writing.
func _temp_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.save.tmp" % slot


## True when there is anything at all to continue in this slot, including a
## slot whose primary is gone but whose backup survives -- otherwise a
## recovered slot would offer "new game" and the next save would wipe the
## backup that was about to rescue it.
func slot_exists(slot: int) -> bool:
	return (FileAccess.file_exists(_save_path(slot))
		or FileAccess.file_exists(_backup_path(slot)))


## What is on disk for a slot, without touching the loaded state. Reads and
## parses, so it is not free, but it runs three times on one menu.
func slot_status(slot: int) -> SlotStatus:
	if not slot_exists(slot):
		return SlotStatus.EMPTY
	if _read_save(_save_path(slot)) != null or _read_save(_backup_path(slot)) != null:
		return SlotStatus.OK
	return SlotStatus.DAMAGED


## Reads and parses one save file. Returns the Dictionary, or null when the
## file is absent, unopenable, or does not parse as a JSON object. Callers
## tell "absent" from "present but unreadable" with FileAccess.file_exists()
## -- the distinction the old code collapsed, and the whole reason a damaged
## save used to look like a new game.
func _read_save(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	# JSON.new().parse(), not JSON.parse_string(): the static helper pushes an
	# engine error with a backtrace on every malformed file. A damaged save is
	# an expected, handled condition here -- the callers report it themselves,
	# in terms a reader can act on -- so it should not also spray parser
	# internals into a player's logcat once per load attempt.
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


func load_slot(slot: int) -> void:
	current_slot = slot
	load_failed = false
	loaded_from_backup = false
	highest_unlocked_level = 1
	completed_levels.clear()
	hydro_bonus_levels.clear()
	par_levels.clear()

	var data = _read_save(_save_path(slot))
	if data != null:
		_apply_save(data)
		return

	# The primary is missing or unreadable. Whether that is a new game or a
	# disaster depends on what else is on disk, so check before assuming.
	var had_primary := FileAccess.file_exists(_save_path(slot))
	var backup = _read_save(_backup_path(slot))
	if backup != null:
		_apply_save(backup)
		loaded_from_backup = true
		if had_primary:
			push_warning("Slot %d: primary save unreadable, recovered from backup." % slot)
		return

	if had_primary or FileAccess.file_exists(_backup_path(slot)):
		# Something was there and none of it parsed. The fields above are
		# already at their new-game defaults, which is indistinguishable
		# from a fresh start -- so flag it, and let save_current_slot()
		# refuse to make the loss permanent.
		load_failed = true
		push_error("Slot %d: save present but unreadable, and no usable backup." % slot)


## Copies one parsed save into the progress fields.
func _apply_save(parsed: Dictionary) -> void:
	highest_unlocked_level = parsed.get("highest_unlocked_level", 1)
	for level_id in parsed.get("completed_levels", []):
		completed_levels[int(level_id)] = true
	# Missing in saves written before the bonus existed -- those simply
	# start with no bonuses earned.
	for level_id in parsed.get("hydro_bonus_levels", []):
		hydro_bonus_levels[int(level_id)] = true
	for level_id in parsed.get("par_levels", []):
		par_levels[int(level_id)] = true


## Writes the active slot. Returns true only if the save is safely on disk.
##
## Never writes the real file in place. The old version opened the live save
## WRITE -- which truncates it to zero before a single byte is written --
## then stored and closed without checking either call. Godot exposes no
## fsync, so after close() the bytes can sit in the page cache for the
## writeback interval (tens of seconds on ext4/f2fs) while the inode on disk
## is already truncated; a power loss anywhere in that window left a
## zero-byte file, which load_slot() then read as a new game. A full
## campaign could be destroyed without the process ever crashing, and a
## nearly-full phone reached the same end with no power event at all, since
## an ENOSPC short write returned normally.
##
## Instead: build a temp file, verify it parses back, keep the outgoing save
## as the backup, then rename the temp over the primary. rename() is atomic,
## so the primary is at every instant either entirely the old save or
## entirely the new one, and never a half-written one. Without fsync the
## ordering of the two is still not guaranteed against a power cut, but the
## worst case degrades from "all progress destroyed" to "the newest save is
## missing and the backup is used instead" -- one level, not a hundred.
func save_current_slot() -> bool:
	if current_slot < 0:
		push_error("No active save slot to save to.")
		return false

	# Refuse to launder an unreadable save into a legitimate-looking reset.
	# See load_failed.
	if load_failed:
		push_error("Slot %d: refusing to overwrite a save that could not be read."
			% current_slot)
		return false

	var data := {
		"highest_unlocked_level": highest_unlocked_level,
		"completed_levels": completed_levels.keys(),
		"hydro_bonus_levels": hydro_bonus_levels.keys(),
		"par_levels": par_levels.keys(),
	}

	var tmp := _temp_path(current_slot)
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Slot %d: could not open a temp file to save into." % current_slot)
		return false
	file.store_string(JSON.stringify(data))
	var write_error := file.get_error()
	file.flush()
	file.close()
	if write_error != OK:
		# A short write -- a full phone is the realistic cause. The primary
		# has not been touched, so the previous save is still intact.
		push_error("Slot %d: save write failed (error %d); previous save left alone."
			% [current_slot, write_error])
		DirAccess.remove_absolute(tmp)
		return false

	# Read it back before trusting it. Cheap next to the cost of finding out
	# later, and it catches a truncation that reported no error.
	if _read_save(tmp) == null:
		push_error("Slot %d: temp save did not read back; previous save left alone."
			% current_slot)
		DirAccess.remove_absolute(tmp)
		return false

	# The save about to be replaced becomes the backup. Copy rather than
	# rename so the primary is never absent, even for an instant.
	if FileAccess.file_exists(_save_path(current_slot)):
		DirAccess.copy_absolute(_save_path(current_slot), _backup_path(current_slot))

	var rename_error := DirAccess.rename_absolute(tmp, _save_path(current_slot))
	if rename_error != OK:
		push_error("Slot %d: could not replace the save (error %d)."
			% [current_slot, rename_error])
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Throws away a slot whose save could not be read, so the player can start
## it over. The only way out of load_failed, and deliberately explicit: it
## destroys the damaged file rather than silently writing over it.
func discard_damaged_slot(slot: int) -> void:
	delete_slot(slot)
	if current_slot == slot:
		load_slot(slot)


func delete_slot(slot: int) -> void:
	for path in [_save_path(slot), _backup_path(slot), _temp_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func mark_level_complete(level_id: int) -> void:
	completed_levels[level_id] = true
	# A finished tutorial is recorded (so its map node gets its check) but
	# never advances the campaign. Without this guard, finishing tutorial 1
	# would set highest_unlocked_level to 902 and unlock all 100 levels.
	if not is_tutorial_level(level_id) and level_id + 1 > highest_unlocked_level:
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
	# The tutorial is where a new game starts, so it is never gated -- and it
	# must not be compared against highest_unlocked_level, which counts
	# campaign levels and would read 901 as "far beyond level 100, locked".
	if is_tutorial_level(level_id):
		return true
	if debug_unlock_all:
		return true
	return level_id <= highest_unlocked_level


func is_tutorial_level(level_id: int) -> bool:
	return level_id >= TUTORIAL_ID_FIRST and level_id <= TUTORIAL_ID_LAST
