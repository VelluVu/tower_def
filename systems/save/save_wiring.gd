class_name SaveWiring
extends SaveSlot

## This game's progress save: the file to edit after copying the system. Saves a
## ProgressData; PlayerProgress owns this node and keeps the game's API to it.

const SAVE_VERSION: int = 1
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
