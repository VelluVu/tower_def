class_name EvolveTree
extends Node


@onready var actor : Node = get_parent()

@onready var all_branches : Array[EvolveBranch] :
	get = _get_all_branches

var available_evolve_level : int = 1
var is_visited : bool = true
var evolve_element : Utils.Element = Utils.Element.Normal
var current_leafs : Array[EvolveLeaf]
var current_random_evolve_choices : Array[EvolveResource]

var can_evolve : bool = false :
	get:
		return current_evolve_level < available_evolve_level

var has_evolve_choices : bool = false :
	get:
		return not current_leafs.is_empty() or not current_random_evolve_choices.is_empty()

var current_evolve_level : int = 1 :
	set = _set_current_evolve_level

var get_current_level : int :
	get: 
		return round((sqrt(100 * (2 * xp_reguirement + 25)) + 50) / 100)

var xp_reguirement : float = 10.0 : 
	get:
		return (pow(available_evolve_level, 2) + available_evolve_level) / 2 * 100 - (available_evolve_level * 100)

var evolve_xp : float = 0.0 :
	set = _set_evolve_xp


signal evolve_level_changed()
signal evolve_level_gained()
signal evolved()


func get_available_evolve_icons() -> Array[Texture2D]:
	var icons : Array[Texture2D]
	for leaf in current_leafs:
		icons.append(leaf.icon)
	return icons


func get_available_evolve_infos() -> Array[String]:
	var infos : Array[String]
	for leaf in current_leafs:
		infos.append(leaf.info)
	return infos


func _ready() -> void:
	available_evolve_level = current_evolve_level
	UISignals.upgrade_option_selected.connect(_on_upgrade_option_selected)


func _on_upgrade_option_selected(_index : int, _building_id : int) -> void:
	if actor.id != _building_id:
		return
	
	if current_leafs.is_empty():
		current_random_evolve_choices[_index].evolve(actor)
		current_random_evolve_choices.clear()
	else:
		current_leafs[_index].evolve(actor)
		current_leafs.clear()
	
	current_evolve_level += 1
	
	evolved.emit()


func _select_evolve_choices() -> void:
	current_leafs = _get_current_leafs()
	
	#if unable to get preset leafs, provide set of random evolve choices.
	if current_leafs.is_empty():
		current_random_evolve_choices = RandomEvolveResourceCollection.get_random_evolve_resources(current_evolve_level, evolve_element, actor.skill)


func _recursive_append_branches(_branch : EvolveBranch, found_branches : Array[EvolveBranch]) -> void:
	found_branches.append(_branch)
	
	if _branch.evolve_branches.is_empty():
		return
	
	for branch_branch in _branch.evolve_branches:
		_recursive_append_branches(branch_branch, found_branches)


func _set_evolve_xp(value : float) -> void:
	if value <= 0.0:
		return
	
	var xp_need_to_level : float = xp_reguirement
	print(actor.name, " current evolve XP: ", evolve_xp, " gained " , str(value - evolve_xp), " XP, " , " next XP reguirement: " ,str(xp_need_to_level))
	evolve_xp = value
	
	if evolve_xp >= xp_need_to_level:
		evolve_xp = evolve_xp - xp_need_to_level
		available_evolve_level += 1
		
		if can_evolve and not has_evolve_choices:
			_select_evolve_choices()
			
		evolve_level_gained.emit()


func _set_current_evolve_level(_evolve_level : int) -> void:
	if _evolve_level == current_evolve_level:
		return
	
	current_evolve_level = _evolve_level
	
	if can_evolve:
		_select_evolve_choices()
		
	evolve_level_changed.emit()
	print(actor.name, " GAINED NEW EVOLVE LEVEL: " + str(current_evolve_level))



func _get_current_leafs() -> Array[EvolveLeaf]:
	current_leafs.clear()
	var branches : Array[EvolveBranch] = _get_all_possible_branches_for_evolve_level(current_evolve_level + 1)
	
	for branch in branches:
		for leaf in branch.evolve_leafs:
			current_leafs.append(leaf)
	
	return current_leafs


func _get_all_branches() -> Array[EvolveBranch]:
	if not all_branches.is_empty():
		return all_branches
	
	var found_branches : Array[EvolveBranch]
	#this is not working ! FIX
	for child in get_children():
		if child is EvolveBranch:
			_recursive_append_branches(child, found_branches)
	
	all_branches.append_array(found_branches)
	return all_branches


func _get_all_possible_branches_for_evolve_level(_evolve_level : int) -> Array[EvolveBranch]:
	var possible_branches : Array[EvolveBranch]
	
	#get only branches with same evolve level and parent is visited
	for branch in all_branches:
		if branch.evolve_level == _evolve_level and branch.get_parent().is_visited:
			possible_branches.append(branch)
				
	return possible_branches
