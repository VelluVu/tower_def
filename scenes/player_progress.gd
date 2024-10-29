extends Node

const FULL_SAVE_PATH : String = "user://player_progress.save"

var _level_progress : int = 1
var level_progress : int :
	get:
		return _level_progress
	set(new_level_number):
		if new_level_number <= _level_progress:
			return
			
		_level_progress = new_level_number

var has_save : bool :
	get:
		return FileAccess.file_exists(FULL_SAVE_PATH)


func load_last_progress_data() -> void:
	print("loading last progress data")
	#load from json file
	if not has_save:
		return
	
	var save_file = FileAccess.open(FULL_SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(save_file.get_as_text())
	save_file.close()
	
	if error != OK:
		return
	
	print(json.data)
	_level_progress = json.data["level_progress"]


func save_progress() -> void:
	print("saving data")
	#save data to json file
	var save_dict = {
		"level_progress" : level_progress
	}
	
	var save_file = FileAccess.open(FULL_SAVE_PATH, FileAccess.WRITE)
	save_file.store_line(JSON.stringify(save_dict))
	save_file.close()


func new_game() -> void:
	print("new game started")
	_reset_progress()


func _reset_progress() -> void:
	print("resetting data")
	_level_progress = 1
	save_progress()
