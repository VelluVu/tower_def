extends Node

const PATH_TO_EVOLVE_RESOURCES : String = "res://scenes/unit/evolve_tree/evolve_resources"
const SLASH : String = "/"
var all_evolve_resources : Array[EvolveResource]


func _ready() -> void:
	_get_all_evolve_resources()


func _get_all_evolve_resources() -> void:
	var directory : DirAccess = DirAccess.open(PATH_TO_EVOLVE_RESOURCES)
	
	if not directory:
		push_warning("No directory in path: ", PATH_TO_EVOLVE_RESOURCES)
		return
	
	var file_names : PackedStringArray = directory.get_files()
	
	for file_name in file_names:
		if file_name.ends_with(".remap"):
			file_name = file_name.replace(".remap", "")
		
		var full_path : String = PATH_TO_EVOLVE_RESOURCES + SLASH + file_name
		
		if ResourceLoader.exists(full_path):
			var resource : EvolveResource = ResourceLoader.load(full_path)
			all_evolve_resources.append(resource)
