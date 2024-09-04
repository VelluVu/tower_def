class_name SceneManager
extends Node

@export var ui_scenes : Array[PackedScene]
@export var level_scenes : Array[PackedScene]
var path_to_level_list : String = "res://scenes/level/levels"
var loaded_level_scenes : Array[Node]
var loaded_ui_scenes : Array[Node]
var current_level :Node = null
enum SceneType {Level, UI}


func _ready() -> void:	
	get_level_list()


func get_level_list():
	var dir := DirAccess.open(path_to_level_list)	
	if not dir:
		print("Cannot find level list from path: ", path_to_level_list)
		return
	
	var level_file_names = dir.get_files()
	
	for level_file_name in level_file_names:
		var full_path : String = path_to_level_list + "/" + level_file_name
		
		if ResourceLoader.exists(full_path):
			var has_scene : bool = false
			
			if !level_scenes.is_empty():
				for level_scene in level_scenes:
					if level_scene.get_path() == full_path:
						has_scene = true
						
			if not has_scene:
				level_scenes.append(ResourceLoader.load(full_path))
		else:
			print("Unable to find level resource from path: ", full_path)


func remove_ending_after_marking_from_file_name(file_name : String, marking : String, ending_length : int) -> String:
	return file_name.right(-file_name.rfind(marking) - 1).left(-ending_length)


func get_level_number_from_level_name(file_name : String) -> int:
	var regex : RegEx = RegEx.new()
	regex.compile("\\d+")
	var result = regex.search(file_name)
	return result.get_string().to_int()


func load_level_by_number(level_number : int, parent_scene : Node):
	for level in level_scenes:
		var current_level_name_formatted : String = remove_ending_after_marking_from_file_name(level.get_path(), "/", 5)
		var current_level_number : int = get_level_number_from_level_name(current_level_name_formatted)
		
		if current_level_number == level_number:
			current_level = level.instantiate()
			parent_scene.add_child(current_level)


func load_scene_by_name(scene_name : String, scene_type : SceneType, parent_scene : Node):
	scene_name = scene_name.to_lower()
	if scene_type == SceneType.Level:
		for level in level_scenes:
			var current_level_name_formatted = remove_ending_after_marking_from_file_name(level.get_path(), "/", 5)

			if current_level_name_formatted == scene_name:
				current_level = level.instantiate()
				parent_scene.add_child(current_level)
				loaded_level_scenes.append(current_level)
				
	elif scene_type == SceneType.UI:
		for ui in ui_scenes:
			var current_ui_name_formatted = remove_ending_after_marking_from_file_name(ui.get_path(), "/", 5)
			
			if current_ui_name_formatted == scene_name:
				var scene = ui.instantiate()
				parent_scene.add_child(scene)
				loaded_ui_scenes.append(scene)


func unload_current_level():
	current_level.queue_free()
	
	
func unload_scene_by_name(scene_name : String, scene_type : SceneType):
	scene_name = scene_name.to_lower()
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
		
