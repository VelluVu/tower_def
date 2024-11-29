extends Node

const PATH_TO_EVOLVE_RESOURCES : String = "res://scenes/unit/evolve_tree/evolve_resources"
const SLASH : String = "/"
var all_evolve_resources : Array[EvolveResource]


func _ready() -> void:
	_get_all_evolve_resources()


func get_possible_evolve_resources(evolve_level : int, evolve_element : Utils.Element, skill : Skill) -> Array[EvolveResource]:
	var possible_resources : Array[EvolveResource]
	
	for resource in all_evolve_resources:
		if evolve_level < resource.evolve_level_reguirement:
			continue
		
		#only accept resources with flagged elements
		#print("Testing elements match in resource ", resource.evolve_name, " , element type: ", evolve_element, " against element type flags value: ", resource.elements)
		if not has_flag(resource.elements, evolve_element):
			continue
		
		if skill != null:
			if skill.base_active_time <= 0.0 and resource.modify_stat_type == Utils.StatType.ActiveDuration:
				continue
		
		#fix this mis match with enum and flags
		if resource.is_skill_modifier:
			#print("Testing skill match in resource ", resource.evolve_name, " , skill type: ", skill.skill_type, " against skill type flags value: ", resource.skill_type)
			#if skill modifier only accept resources with flagged skill types
			if not has_flag(resource.skill_type, skill.skill_type):
				continue
		
		possible_resources.append(resource)
	
	return possible_resources


func get_random_evolve_resources(evolve_level : int, evolve_element : Utils.Element, skill : Skill, max_evolve_resources : int = 4) -> Array[EvolveResource]:
	var possible_resources : Array[EvolveResource] = get_possible_evolve_resources(evolve_level, evolve_element, skill)
	
	if possible_resources.is_empty():
		push_warning(name, " NO POSSIBLE RESOURCES!")
		return possible_resources
	
	var resources_to_return : Array[EvolveResource]
	
	for n in max_evolve_resources:
		var random_resource : EvolveResource = possible_resources.pick_random()
		resources_to_return.append(random_resource)
		possible_resources.erase(random_resource)
	
	return resources_to_return

#IS THIS WORKING ?!? !??!? ?!??
func has_flag(a : int, b : int) -> bool:
	#print("test if in flags " , a , " is ", b, " result: ", (a & b), " is: ", ((a&b) == b))
	return (a & b) == b


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
