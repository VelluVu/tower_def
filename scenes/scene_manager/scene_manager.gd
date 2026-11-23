class_name SceneManager
extends Node


const PATH_TO_LEVEL_FOLDER : String = "res://scenes/level/levels"
const PATH_TO_UI_FOLDER : String = "res://scenes/ui"
const LEVEL_FOLDER_PATH_NONEXISTENT_WARNING : String = " Cannot find level folder in path: "
const UI_FOLDER_PATH_NONEXISTENT_WARNING : String = " Cannot find ui folder in path: "
const LEVEL_RESOURCE_NONEXISTENT_WARNING : String = " Unable to find level resource in path: "
const UI_RESOURCE_NONEXISTENT_WARNING : String = " Unable to find ui resource in path: "
const FOLDER_PATH_WARNING : String = " Unable to find folder in path: "
const INVALID_RESOURCE_IN_PATH_WARNING : String = " Unable to find resource in path: "
const LEVEL_NUMBER_MISSING_WARNING : String = " Level file name has no level number, skipped: "
const SCENE_ENDING : String = ".tscn"
const SLASH : String = "/"
const ENDING_CHAR_COUNT : int = 5

@export var ui_scenes : Array[PackedScene]
@export var level_scenes : Array[PackedScene]

#the scene files found at start, loaded only when first shown: loading all 48 levels and every UI scene up front
#made the start slow and kept them all in memory
var level_paths : Dictionary[int, String] = {}
#file name without .tscn, lower case -> path; the first file found under a name wins
var ui_paths : Dictionary[String, String] = {}

var current_level : Node = null
var current_level_number : int = 0
var current_level_mode : Utils.LevelMode = Utils.LevelMode.Normal
var loaded_ui_scenes : Array[Node]
var loaded_level_scenes : Array[Node]

enum SceneType {Level, UI}


func load_level_by_number(level_number : int, parent_scene : Node, mode : Utils.LevelMode = Utils.LevelMode.Normal) -> void:
	if not level_paths.has(level_number):
		push_warning(name, LEVEL_RESOURCE_NONEXISTENT_WARNING, level_number)
		return

	var level : PackedScene = load(level_paths[level_number])
	current_level_number = level_number
	current_level_mode = mode
	current_level = level.instantiate()
	#set before _ready, which builds the waves for the mode
	if current_level is Level:
		current_level.mode = mode
	parent_scene.add_child(current_level)


func load_scene_by_name(scene_name : String, scene_type : SceneType, parent_scene : Node) -> Node:
	scene_name = scene_name.to_lower()
	
	if scene_type == SceneType.Level:
		for level_path in level_paths.values():
			if _get_scene_name(level_path) == scene_name:
				current_level = (load(level_path) as PackedScene).instantiate()
				parent_scene.add_child(current_level)
				loaded_level_scenes.append(current_level)
				return current_level

	elif scene_type == SceneType.UI and ui_paths.has(scene_name):
		var scene : Node = (load(ui_paths[scene_name]) as PackedScene).instantiate()
		parent_scene.add_child(scene)
		loaded_ui_scenes.append(scene)
		return scene

	return null


func get_last_level_number() -> int:
	return level_paths.keys().max() if not level_paths.is_empty() else 0


func get_level_count() -> int:
	return level_paths.size()


func is_in_level() -> bool:
	return current_level != null


func is_scene_loaded(scene_name : String, scene_type : SceneType) -> bool:
	scene_name = scene_name.to_lower()
	scene_name = scene_name.replace("_", "")
	
	if scene_type == SceneType.Level:
		for scene in loaded_level_scenes:
			var current_scene_name : String = scene.name.to_lower()
			
			if current_scene_name == scene_name:
				return true
	
	if scene_type == SceneType.UI:
		for scene in loaded_ui_scenes:
			var current_scene_name : String = scene.name.to_lower()
			
			if current_scene_name == scene_name:
				return true
	
	return false


func unload_all_ui_scenes() -> void:
	for scene in loaded_ui_scenes:
		scene.queue_free()
	loaded_ui_scenes.clear()


func unload_current_level() -> void:
	if is_instance_valid(current_level):
		current_level.queue_free()
	current_level = null


func unload_scene_by_name(scene_name : String, scene_type : SceneType) -> void:
	scene_name = scene_name.to_snake_case()
	
	if scene_type == SceneType.Level:
		for scene in loaded_level_scenes:
			var current_scene_name : String = scene.name.to_snake_case()
			
			if current_scene_name == scene_name:
				loaded_level_scenes.erase(scene)
				scene.queue_free()
				return
				
	elif scene_type == SceneType.UI:
		for scene in loaded_ui_scenes:
			var current_scene_name : String = scene.name.to_snake_case()
			
			if current_scene_name == scene_name:
				loaded_ui_scenes.erase(scene)
				scene.queue_free()
				return


func _ready() -> void:
	#scenes set in the inspector count too, ahead of the folders
	for scene in ui_scenes:
		_add_ui_path(scene.resource_path)
	for scene in level_scenes:
		_add_level_path(scene.resource_path)
	_get_ui_packed_scenes_from_project_folder()
	_get_level_packed_scenes_from_project_folder()


func _get_ui_packed_scenes_from_project_folder() -> void:
	var dir := DirAccess.open(PATH_TO_UI_FOLDER)
	if not dir:
		push_warning(name, UI_FOLDER_PATH_NONEXISTENT_WARNING, PATH_TO_UI_FOLDER)
		return
	
	var file_names : PackedStringArray = dir.get_files()
	_find_and_append_all_ui_scenes_from_file_names_in_directory_path(file_names, PATH_TO_UI_FOLDER)
	
	var directory_names : PackedStringArray = dir.get_directories()
	
	if directory_names.is_empty():
		return
	
	for directory_name in directory_names:
		var directory_path : String = PATH_TO_UI_FOLDER + SLASH + directory_name
		_recursively_search_directory_for_ui_files(directory_path)


func _recursively_search_directory_for_ui_files(directory_path : String) -> void:
	var dir := DirAccess.open(directory_path)
	
	if not dir:
		push_warning(name, FOLDER_PATH_WARNING, directory_path)
		return

	var file_names : PackedStringArray = dir.get_files()
	_find_and_append_all_ui_scenes_from_file_names_in_directory_path(file_names, directory_path)
	
	var directory_names : PackedStringArray = dir.get_directories()
	if directory_names.is_empty():
		return
	
	for directory_name in directory_names:
		var new_directory_path : String = directory_path + SLASH + directory_name
		_recursively_search_directory_for_ui_files(new_directory_path)


func _find_and_append_all_ui_scenes_from_file_names_in_directory_path(file_names : PackedStringArray, directory_path : String) -> void:
	if file_names.is_empty():
		return
	
	for file_name in file_names:
		if file_name.ends_with(".remap"):
			file_name = file_name.replace(".remap", "")
		if file_name.ends_with(".uid"):
			file_name = file_name.replace(".uid", "")
			
		var file_path : String = directory_path + SLASH + file_name

		#scenes only: other files (scripts, .import files in an export) are no reason to warn
		if not file_path.ends_with(SCENE_ENDING):
			continue

		if not ResourceLoader.exists(file_path):
			push_warning(name, INVALID_RESOURCE_IN_PATH_WARNING , file_path)
			continue

		_add_ui_path(file_path)


func _get_level_packed_scenes_from_project_folder() -> void:
	var dir := DirAccess.open(PATH_TO_LEVEL_FOLDER)	
	if not dir:
		push_warning(name, LEVEL_FOLDER_PATH_NONEXISTENT_WARNING, PATH_TO_LEVEL_FOLDER)
		return
	
	var level_file_names = dir.get_files()
	
	for level_file_name in level_file_names:
		if level_file_name.ends_with(".remap"):
			level_file_name = level_file_name.replace(".remap", "")
			
		var full_path : String = PATH_TO_LEVEL_FOLDER + SLASH + level_file_name
		
		if not full_path.ends_with(SCENE_ENDING):
			continue

		if _get_level_number_from_level_name(_get_scene_name(full_path)) <= 0:
			push_warning(name, LEVEL_NUMBER_MISSING_WARNING, full_path)
		elif ResourceLoader.exists(full_path):
			_add_level_path(full_path)
		else:
			push_warning(name, LEVEL_RESOURCE_NONEXISTENT_WARNING, full_path)


func _add_ui_path(path : String) -> void:
	var scene_name : String = _get_scene_name(path)
	if not ui_paths.has(scene_name):
		ui_paths[scene_name] = path


func _add_level_path(path : String) -> void:
	var level_number : int = _get_level_number_from_level_name(_get_scene_name(path))
	if not level_paths.has(level_number):
		level_paths[level_number] = path


func _get_scene_name(path : String) -> String:
	return _remove_ending_after_marking_from_file_name(path, SLASH, ENDING_CHAR_COUNT).to_lower()


func _remove_ending_after_marking_from_file_name(file_name : String, marking : String, ending_length : int) -> String:
	return file_name.right(-file_name.rfind(marking) - 1).left(-ending_length)


func _get_level_number_from_level_name(file_name : String) -> int:
	var regex : RegEx = RegEx.new()
	regex.compile("\\d+")
	var result : RegExMatch = regex.search(file_name)
	#0 = no number in the name: not a level
	return result.get_string().to_int() if result != null else 0
