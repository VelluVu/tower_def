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
const UI_SCENE_ALREADY_EXISTS_IN_LIST : String = " UI scene already exists in ui scenes list, path to scene: "
const SCENE_ENDING : String = ".tscn"
const SLASH : String = "/"
const ENDING_CHAR_COUNT : int = 5

@export var ui_scenes : Array[PackedScene]
@export var level_scenes : Array[PackedScene]

var current_level : Node = null
var loaded_ui_scenes : Array[Node]
var loaded_level_scenes : Array[Node]

enum SceneType {Level, UI}


func load_level_by_number(level_number : int, parent_scene : Node):
	for level in level_scenes:
		var current_level_name_formatted : String = _remove_ending_after_marking_from_file_name(level.get_path(), SLASH, ENDING_CHAR_COUNT)
		var current_level_number : int = _get_level_number_from_level_name(current_level_name_formatted)
		
		if current_level_number == level_number:
			current_level = level.instantiate()
			parent_scene.add_child(current_level)


func load_scene_by_name(scene_name : String, scene_type : SceneType, parent_scene : Node):
	scene_name = scene_name.to_lower()
	
	if scene_type == SceneType.Level:
		for level in level_scenes:
			var current_level_name_formatted = _remove_ending_after_marking_from_file_name(level.get_path(), SLASH, ENDING_CHAR_COUNT)

			if current_level_name_formatted == scene_name:
				current_level = level.instantiate()
				parent_scene.add_child(current_level)
				loaded_level_scenes.append(current_level)
				return current_level
				
	elif scene_type == SceneType.UI:
		for ui in ui_scenes:
			var current_ui_name_formatted = _remove_ending_after_marking_from_file_name(ui.get_path(), SLASH, ENDING_CHAR_COUNT)
			
			if current_ui_name_formatted == scene_name:
				var scene = ui.instantiate()
				parent_scene.add_child(scene)
				loaded_ui_scenes.append(scene)
				return scene
				
	return null


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


func unload_current_level():
	current_level.queue_free()
	
	
func unload_scene_by_name(scene_name : String, scene_type : SceneType):
	scene_name = scene_name.to_lower()
	scene_name = scene_name.replace("_", "")
	
	if scene_type == SceneType.Level:
		for scene in loaded_level_scenes:
			var current_scene_name : String = scene.name.to_lower()
			
			if current_scene_name == scene_name:
				loaded_level_scenes.erase(scene)
				scene.queue_free()
				
	elif scene_type == SceneType.UI:
		for scene in loaded_ui_scenes:
			var current_scene_name : String = scene.name.to_lower()
			
			if current_scene_name == scene_name:
				loaded_ui_scenes.erase(scene)
				scene.queue_free()


func _ready() -> void:
	_get_ui_packed_scenes_from_project_folder()	
	_get_level_packed_scenes_from_project_folder()


func _get_ui_packed_scenes_from_project_folder():
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


func _recursively_search_directory_for_ui_files(directory_path : String):
	var dir := DirAccess.open(directory_path)
	
	if not dir:
		push_warning(name, FOLDER_PATH_WARNING, directory_path)
		
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
		var file_path : String = directory_path + SLASH + file_name
		
		if not ResourceLoader.exists(file_path):
			push_warning(name, INVALID_RESOURCE_IN_PATH_WARNING , file_path)
			continue
		
		if not file_path.contains(SCENE_ENDING):
			continue
			
		if not ui_scenes.is_empty():
			var has_scene : bool = false
			
			for ui_scene in ui_scenes:
				if ui_scene.get_path() == file_path:
					has_scene = true
					
			if has_scene:
				print(name, UI_SCENE_ALREADY_EXISTS_IN_LIST, file_path)
				continue
		
		ui_scenes.append(ResourceLoader.load(file_path))
	


func _get_level_packed_scenes_from_project_folder():
	var dir := DirAccess.open(PATH_TO_LEVEL_FOLDER)	
	if not dir:
		push_warning(name, LEVEL_FOLDER_PATH_NONEXISTENT_WARNING, PATH_TO_LEVEL_FOLDER)
		return
	
	var level_file_names = dir.get_files()
	
	for level_file_name in level_file_names:
		var full_path : String = PATH_TO_LEVEL_FOLDER + SLASH + level_file_name
		
		if ResourceLoader.exists(full_path):
			var has_scene : bool = false
			
			if !level_scenes.is_empty():
				for level_scene in level_scenes:
					if level_scene.get_path() == full_path:
						has_scene = true
						
			if not has_scene:
				level_scenes.append(ResourceLoader.load(full_path))
		else:
			push_warning(name, LEVEL_RESOURCE_NONEXISTENT_WARNING, full_path)


func _remove_ending_after_marking_from_file_name(file_name : String, marking : String, ending_length : int) -> String:
	return file_name.right(-file_name.rfind(marking) - 1).left(-ending_length)


func _get_level_number_from_level_name(file_name : String) -> int:
	var regex : RegEx = RegEx.new()
	regex.compile("\\d+")
	var result = regex.search(file_name)
	return result.get_string().to_int()
