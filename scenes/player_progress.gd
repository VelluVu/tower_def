extends Node

## The player's level progress, saved through the save system (SaveWiring).

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


func save_progress() -> void:
	_save.save_game()


func new_game() -> void:
	_save.progress = ProgressData.new()
	save_progress()
