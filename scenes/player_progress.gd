extends Node

## The player's level progress and talents, saved through the save system (SaveWiring).

signal talents_changed()

const NO_SAVE_LOADED_WARNING : String = "No progress loaded, keeping the current progress"

var _save : SaveWiring = SaveWiring.new()

## Only ever goes up; new_game() is the way back to level 1.
var level_progress : int :
	get:
		return _save.progress.level_progress
	set(new_level_number):
		if new_level_number <= _save.progress.level_progress:
			return

		_save.progress.level_progress = new_level_number

var has_save : bool :
	get:
		return _save.has_save()


func _init() -> void:
	add_child(_save)


func load_last_progress_data() -> void:
	if not _save.load_game():
		push_warning(NO_SAVE_LOADED_WARNING)

	_add_missing_clear_points()
	talents_changed.emit()


#levels cleared before talent points existed still earn the point for the clear
func _add_missing_clear_points() -> void:
	for level_number in range(1, _save.progress.level_progress):
		if not _save.progress.level_talent_points.has(level_number):
			_save.progress.level_talent_points[level_number] = 1


func save_progress() -> void:
	_save.save_game()


func new_game() -> void:
	_save.progress = ProgressData.new()
	save_progress()
	talents_changed.emit()


## The tree's ranks, node id -> rank. Read only; change ranks through set_talent_rank.
func get_talent_ranks(tree_id : StringName) -> Dictionary:
	return _save.progress.talent_ranks.get(tree_id, {})


func get_talent_points_earned() -> int:
	var earned : int = 0

	for level_number in _save.progress.level_talent_points:
		earned += _save.progress.level_talent_points[level_number]

	return earned


func get_talent_points_spent() -> int:
	var spent : int = 0

	for tree_id in _save.progress.talent_ranks:
		spent += TalentRules.get_spent(_save.progress.talent_ranks[tree_id])

	return spent


func get_talent_points_unspent() -> int:
	return get_talent_points_earned() - get_talent_points_spent()


func get_level_talent_points(level_number : int) -> int:
	return _save.progress.level_talent_points.get(level_number, 0)


## Only Normal is played and saved so far; the other modes have no points yet.
func get_level_mode_talent_points(level_number : int, mode : Utils.LevelMode) -> int:
	if mode != Utils.LevelMode.Normal:
		return 0

	return get_level_talent_points(level_number)


## Keeps the best result of the level and returns how many points it added.
func record_level_talent_points(level_number : int, points : int) -> int:
	var best : int = get_level_talent_points(level_number)

	if points <= best:
		return 0

	_save.progress.level_talent_points[level_number] = points
	talents_changed.emit()
	return points - best


func set_talent_rank(tree_id : StringName, node_id : StringName, rank : int) -> void:
	if not _save.progress.talent_ranks.has(tree_id):
		_save.progress.talent_ranks[tree_id] = {}

	var ranks : Dictionary = _save.progress.talent_ranks[tree_id]

	if rank <= 0:
		ranks.erase(node_id)
	else:
		ranks[node_id] = rank

	save_progress()
	talents_changed.emit()


## Respec is free: every rank of the tree comes back as unspent points.
func reset_talent_tree(tree_id : StringName) -> void:
	_save.progress.talent_ranks.erase(tree_id)
	save_progress()
	talents_changed.emit()
