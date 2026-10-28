class_name SaveWiring
extends SaveSlot

## This game's progress save: the file to edit after copying the system. Saves a
## ProgressData; PlayerProgress owns this node and keeps the game's API to it.

const SAVE_VERSION: int = 4
## Versions 2 and 3 put new levels in; the level at the number and every later
## one moved up. 2: the Broodmother's Lair at 6. 3: two cave levels before it
## (at 6) and the human bridge after it (at 9). 4: two levels between the lair
## and the bridge (at 9).
const INSERTED_LEVEL: int = 6
const INSERTED_COUNT_V3: int = 2
const BRIDGE_LEVEL_V3: int = 9
const AFTER_LAIR_LEVEL_V4: int = 9
const AFTER_LAIR_COUNT_V4: int = 2
const SAVE_PATH: String = "user://player_progress.tres"

## The JSON save from before this system. Imported once, then renamed to
## LEGACY_DONE_SUFFIX so it is kept for hand recovery but never read again.
const LEGACY_JSON_PATH: String = "user://player_progress.save"
const LEGACY_DONE_SUFFIX: String = ".old"
const LEGACY_LEVEL_KEY: String = "level_progress"

const LEGACY_UNREADABLE_WARNING: String = "Old save %s could not be read, starting from level 1"
const LEGACY_RENAME_WARNING: String = "Old save %s could not be renamed: %s"

var progress: ProgressData = ProgressData.new()


func _init() -> void:
	save_path = SAVE_PATH
	version = SAVE_VERSION
	version_property = &"save_version"
	# Progress is saved when a level is cleared; saving on quit would create a save
	# (and a Continue button) for a player who never started a game.
	save_on_quit = false


func has_save() -> bool:
	return super.has_save() or FileAccess.file_exists(LEGACY_JSON_PATH)


func save_game() -> bool:
	return write(progress)


## The current progress is left untouched when nothing could be loaded.
func load_game() -> bool:
	_import_legacy_json()
	var loaded: ProgressData = read() as ProgressData
	if loaded == null:
		return false

	progress = loaded
	return true


func _migrate(resource: Resource, from_version: int) -> void:
	var data: ProgressData = resource as ProgressData
	if data == null:
		return
	if from_version < 2:
		_shift_levels(data, INSERTED_LEVEL, 1)
	if from_version < 3:
		_shift_levels(data, INSERTED_LEVEL, INSERTED_COUNT_V3)
		_shift_levels(data, BRIDGE_LEVEL_V3, 1)
	if from_version < 4:
		_shift_levels(data, AFTER_LAIR_LEVEL_V4, AFTER_LAIR_COUNT_V4)


## Moves the progress of level `inserted` and later up by `count`. A player who
## had only unlocked `inserted` now has the first new level there unlocked instead.
func _shift_levels(data: ProgressData, inserted: int, count: int) -> void:
	if data.level_progress > inserted:
		data.level_progress += count
	var shifted: Dictionary[int, int] = {}
	for level_number: int in data.level_talent_points:
		var new_number: int = level_number + count if level_number >= inserted else level_number
		shifted[new_number] = data.level_talent_points[level_number]
	data.level_talent_points = shifted


## Turns the old JSON save into a versioned save. A newer save always wins over it.
func _import_legacy_json() -> void:
	if not FileAccess.file_exists(LEGACY_JSON_PATH) or super.has_save():
		return

	var imported: ProgressData = ProgressData.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_JSON_PATH))
	var level: Variant = data.get(LEGACY_LEVEL_KEY) if data is Dictionary else null
	if level is float or level is int:
		imported.level_progress = maxi(int(level), 1)
	else:
		push_warning(LEGACY_UNREADABLE_WARNING % LEGACY_JSON_PATH)

	# Keep the old file until the new one is safely written.
	if not write(imported):
		return

	var err: Error = DirAccess.rename_absolute(LEGACY_JSON_PATH, LEGACY_JSON_PATH + LEGACY_DONE_SUFFIX)
	if err != OK:
		push_warning(LEGACY_RENAME_WARNING % [LEGACY_JSON_PATH, error_string(err)])
