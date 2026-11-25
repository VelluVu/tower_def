class_name SaveWiring
extends SaveSlot

## This game's progress save: the file to edit after copying the system. Saves a
## ProgressData; PlayerProgress owns this node and keeps the game's API to it.

const SAVE_VERSION: int = 9
## Versions 2 and 3 put new levels in; the level at the number and every later
## one moved up. 2: the Broodmother's Lair at 6. 3: two cave levels before it
## (at 6) and the human bridge after it (at 9). 4: two levels between the lair
## and the bridge (at 9). 5: two field levels before the Dragonslayer's Camp (at 18).
## 6: twelve levels per area: a cave level at 10, eight swamp levels before Hydra's
## Mire (at 16) and seven field levels before the camp (at 29), in that order.
## 7: 60 levels: six desert levels before the Bone Colossus (at 42), then six
## volcano levels before the Throne of Embers (at 54, after the first shift).
## 8: the Broodmother's Lair moves from 8 to 12, the Caves' end; 9-12 close up to 8-11.
## 9: the caves' new route: Bat Roost and Echo Crossing swap (6, 7), so do Collapsed
## Tunnels and Crystal Deep (8, 9).
const INSERTED_LEVEL: int = 6
const INSERTED_COUNT_V3: int = 2
const BRIDGE_LEVEL_V3: int = 9
const AFTER_LAIR_LEVEL_V4: int = 9
const AFTER_LAIR_COUNT_V4: int = 2
const BEFORE_CAMP_LEVEL_V5: int = 18
const BEFORE_CAMP_COUNT_V5: int = 2
const CAVE_LEVEL_V6: int = 10
const BEFORE_HYDRA_LEVEL_V6: int = 16
const BEFORE_HYDRA_COUNT_V6: int = 8
const BEFORE_CAMP_LEVEL_V6: int = 29
const BEFORE_CAMP_COUNT_V6: int = 7
const BEFORE_COLOSSUS_LEVEL_V7: int = 42
const BEFORE_THRONE_LEVEL_V7: int = 54
const AREA_HALF_COUNT_V7: int = 6
const LAIR_FROM_V8: int = 8
const LAIR_TO_V8: int = 12
const SWAPS_V9: Array[Vector2i] = [Vector2i(6, 7), Vector2i(8, 9)]
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
	if from_version < 5:
		_shift_levels(data, BEFORE_CAMP_LEVEL_V5, BEFORE_CAMP_COUNT_V5)
	if from_version < 6:
		_shift_levels(data, CAVE_LEVEL_V6, 1)
		_shift_levels(data, BEFORE_HYDRA_LEVEL_V6, BEFORE_HYDRA_COUNT_V6)
		_shift_levels(data, BEFORE_CAMP_LEVEL_V6, BEFORE_CAMP_COUNT_V6)
	if from_version < 7:
		_shift_levels(data, BEFORE_COLOSSUS_LEVEL_V7, AREA_HALF_COUNT_V7)
		_shift_levels(data, BEFORE_THRONE_LEVEL_V7, AREA_HALF_COUNT_V7)
	if from_version < 8:
		_move_level(data, LAIR_FROM_V8, LAIR_TO_V8)
	if from_version < 9:
		for swap: Vector2i in SWAPS_V9:
			_move_level(data, swap.x, swap.y)


## Moves the progress of level `inserted` and later up by `count`. A player who
## had only unlocked `inserted` now has the first new level there unlocked instead.
func _shift_levels(data: ProgressData, inserted: int, count: int) -> void:
	if data.level_progress > inserted:
		data.level_progress += count
	data.level_talent_points = _shift_points(data.level_talent_points, inserted, count)
	# the other modes' points (Hard, from save version 4 on) are per level number too
	for mode: int in data.mode_talent_points:
		var points: Dictionary[int, int] = {}
		points.assign(data.mode_talent_points[mode])
		data.mode_talent_points[mode] = _shift_points(points, inserted, count)


## Moves level `from` to `to` (later), the levels between one down. Progress is one
## number, so a player part-way through them (the moved level cleared, `to` not
## yet) goes back one: what they cleared stays cleared, the moved level is ahead.
func _move_level(data: ProgressData, from: int, to: int) -> void:
	if data.level_progress > from and data.level_progress <= to:
		data.level_progress -= 1
	if data.map_revealed_level > from and data.map_revealed_level <= to:
		data.map_revealed_level -= 1
	data.level_talent_points = _moved_points(data.level_talent_points, from, to)
	for mode: int in data.mode_talent_points:
		var points: Dictionary[int, int] = {}
		points.assign(data.mode_talent_points[mode])
		data.mode_talent_points[mode] = _moved_points(points, from, to)
	data.survival_best_waves = _moved_points(data.survival_best_waves, from, to)


func _moved_points(points: Dictionary[int, int], from: int, to: int) -> Dictionary[int, int]:
	var moved: Dictionary[int, int] = {}
	for level_number: int in points:
		var new_number: int = level_number
		if level_number == from:
			new_number = to
		elif level_number > from and level_number <= to:
			new_number = level_number - 1
		moved[new_number] = points[level_number]
	return moved


func _shift_points(points: Dictionary[int, int], inserted: int, count: int) -> Dictionary[int, int]:
	var shifted: Dictionary[int, int] = {}
	for level_number: int in points:
		var new_number: int = level_number + count if level_number >= inserted else level_number
		shifted[new_number] = points[level_number]
	return shifted


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
