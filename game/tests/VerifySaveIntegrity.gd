extends Node

## Headless check for save durability. Run from the game/ directory:
##   godot --headless res://tests/VerifySaveIntegrity.tscn
##
## Everything here is about one question: can a save be lost or silently
## reset? The old writer opened the live file WRITE (truncating it), stored,
## and closed, checking neither call -- so an interrupted write, or a short
## write on a full phone, left a zero-byte file that load_slot() then read
## as a brand new game. The player saw "(continue)", a campaign back at
## level 1, and no explanation; their next win wrote that reset over the top
## and made it permanent.
##
## The suite therefore corrupts saves the way a device would -- truncation,
## a half-written file, garbage -- and checks the recovery, rather than only
## checking that a good save round-trips.
##
## Runs on TEST_SLOT, deliberately outside the 0..SAVE_SLOT_COUNT-1 range the
## game uses, so it can never touch a real save on the developer's machine.

const TEST_SLOT := 99

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _path() -> String:
	return GameState._save_path(TEST_SLOT)


func _backup() -> String:
	return GameState._backup_path(TEST_SLOT)


func _temp() -> String:
	return GameState._temp_path(TEST_SLOT)


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe() -> void:
	GameState.delete_slot(TEST_SLOT)
	GameState.load_failed = false
	GameState.loaded_from_backup = false


## Puts a known campaign into the slot and saves it twice, so both a primary
## and a backup exist. Returns after the second save.
func _seed(first_level: int, second_level: int) -> void:
	_wipe()
	GameState.load_slot(TEST_SLOT)
	GameState.highest_unlocked_level = first_level
	GameState.completed_levels = {first_level - 1: true}
	GameState.save_current_slot()
	GameState.highest_unlocked_level = second_level
	GameState.completed_levels = {second_level - 1: true}
	GameState.save_current_slot()


func _ready() -> void:
	print("Round trip")
	_wipe()
	GameState.load_slot(TEST_SLOT)
	GameState.highest_unlocked_level = 42
	GameState.completed_levels = {41: true}
	GameState.par_levels = {8: true}
	GameState.hydro_bonus_levels = {7: true}
	_check(GameState.save_current_slot(), "save reports success")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.highest_unlocked_level == 42, "highest_unlocked_level survives")
	_check(GameState.completed_levels.has(41), "completed_levels survives")
	_check(GameState.par_levels.has(8), "par_levels survives")
	_check(GameState.hydro_bonus_levels.has(7), "hydro_bonus_levels survives")
	_check(not GameState.load_failed, "a clean load does not set load_failed")
	_check(not GameState.loaded_from_backup, "a clean load does not use the backup")

	print("Atomic write")
	_check(not FileAccess.file_exists(_temp()), "no temp file left behind after a save")
	_seed(10, 20)
	_check(FileAccess.file_exists(_backup()), "second save creates a backup")
	var bak = JSON.parse_string(FileAccess.open(_backup(), FileAccess.READ).get_as_text())
	_check(bak.get("highest_unlocked_level") == 10,
		"the backup holds the PREVIOUS save, not the current one")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.highest_unlocked_level == 20, "the primary holds the current save")

	print("Recovery: zero-byte primary (the interrupted-write case)")
	_seed(10, 20)
	_write_raw(_path(), "")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.highest_unlocked_level == 10, "falls back to the backup")
	_check(GameState.loaded_from_backup, "reports that it used the backup")
	_check(not GameState.load_failed, "a usable backup is not a failure")

	print("Recovery: garbage primary")
	_seed(10, 20)
	_write_raw(_path(), "{\"highest_unlocked_lev")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.highest_unlocked_level == 10, "a half-written file falls back too")
	_write_raw(_path(), "not json at all")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.highest_unlocked_level == 10, "so does outright garbage")
	_write_raw(_path(), "[1,2,3]")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.highest_unlocked_level == 10, "so does valid JSON of the wrong shape")

	print("Recovery: missing primary")
	_seed(10, 20)
	DirAccess.remove_absolute(_path())
	_check(GameState.slot_exists(TEST_SLOT),
		"a slot with only a backup still counts as occupied")
	_check(GameState.slot_status(TEST_SLOT) == GameState.SlotStatus.OK,
		"...and reads as OK, not EMPTY -- it must not be offered as a new game")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.highest_unlocked_level == 10, "recovers from the backup alone")

	print("Unrecoverable: both copies damaged")
	_seed(10, 20)
	_write_raw(_path(), "")
	_write_raw(_backup(), "")
	GameState.load_slot(TEST_SLOT)
	_check(GameState.load_failed, "load_failed is set")
	_check(GameState.slot_status(TEST_SLOT) == GameState.SlotStatus.DAMAGED,
		"slot reads as DAMAGED, never EMPTY")
	_check(GameState.highest_unlocked_level == 1,
		"progress is at defaults (which is exactly why it must not be saved)")

	print("A damaged save is never overwritten")
	_check(not GameState.save_current_slot(), "save_current_slot() refuses and says so")
	GameState.mark_level_complete(1)
	_check(GameState.slot_status(TEST_SLOT) == GameState.SlotStatus.DAMAGED,
		"winning a level does not launder the reset onto disk")
	var raw := FileAccess.open(_path(), FileAccess.READ)
	_check(raw.get_length() == 0, "the damaged file is left exactly as it was")
	raw.close()

	print("Discarding a damaged slot is the way out")
	GameState.discard_damaged_slot(TEST_SLOT)
	_check(not GameState.load_failed, "load_failed clears")
	_check(GameState.slot_status(TEST_SLOT) == GameState.SlotStatus.EMPTY, "slot is empty")
	GameState.highest_unlocked_level = 5
	_check(GameState.save_current_slot(), "saving works again")

	print("Housekeeping")
	_seed(10, 20)
	GameState.delete_slot(TEST_SLOT)
	_check(not FileAccess.file_exists(_path()), "delete removes the primary")
	_check(not FileAccess.file_exists(_backup()), "delete removes the backup")
	_check(not FileAccess.file_exists(_temp()), "delete removes any temp")
	_check(not GameState.slot_exists(TEST_SLOT), "the slot is gone")

	_wipe()
	GameState.current_slot = -1
	_check(not GameState.save_current_slot(), "no active slot is still refused")

	if _failures == 0:
		print("SAVE INTEGRITY PASS")
	else:
		printerr("SAVE INTEGRITY FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
