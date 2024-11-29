class_name EvolveTree
extends Node


@onready var actor : Node = get_parent()

@onready var all_branches : Array[EvolveBranch] :
	get = _get_all_branches

@export var current_evolve_level : int = 0 :
	set = _set_current_evolve_level

@export var first_evolve_level_xp_reguirement : float = 10.0

var is_current_evolve_option_selected : bool = false : 
	set = _set_is_current_evolve_option_selected
	
var available_evolve_level : int = -1
var is_visited : bool = true
var evolve_element : Utils.Element = Utils.Element.Normal

var next_evolve_xp_reguirement : float :
	get:
		var evolve_level_multiplier : float = float(available_evolve_level) + 1.0
		next_evolve_xp_reguirement = first_evolve_level_xp_reguirement * evolve_level_multiplier
		return next_evolve_xp_reguirement

var evolve_xp : float = 0.0 :
	set = _set_evolve_xp

var current_leafs : Array[EvolveLeaf]

var current_random_evolve_choices : Array[EvolveResource] :
	get:
		return current_random_evolve_choices
		

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
	is_current_evolve_option_selected = true
	current_leafs = _get_current_leafs()
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
	
	is_current_evolve_option_selected = true
	
	if current_evolve_level < available_evolve_level:
		current_evolve_level += 1
	
	evolved.emit()


func _set_evolve_xp(value : float) -> void:
	if value <= 0.0:
		return
		
	print(actor.name, " current evolve XP: ", evolve_xp, " gained " ,str(value), " XP, " , " next XP reguirement: " ,str(next_evolve_xp_reguirement))
	evolve_xp = value
	
	if evolve_xp >= next_evolve_xp_reguirement:
		evolve_xp = evolve_xp - next_evolve_xp_reguirement
		available_evolve_level += 1
		
		#what if selected current evolve option
		if is_current_evolve_option_selected:
			current_evolve_level += 1
		
		evolve_level_gained.emit()


func _set_is_current_evolve_option_selected(value : bool) -> void:
	if is_current_evolve_option_selected == value:
		return
	
	is_current_evolve_option_selected = value
	actor.evolve_glow.visible = not is_current_evolve_option_selected


func _set_current_evolve_level(_evolve_level : int) -> void:
	if _evolve_level == current_evolve_level:
		return
	
	is_current_evolve_option_selected = false
	current_evolve_level = _evolve_level
	current_leafs = _get_current_leafs()
	
	#fix this !
	#if unable to get preset leafs, provide set of random evolve choices.
	if current_leafs.is_empty():
		current_random_evolve_choices = RandomEvolveResourceCollection.get_random_evolve_resources(current_evolve_level, evolve_element, actor.skill)
		
	evolve_level_changed.emit()
	print(actor.name, " GAINED NEW EVOLVE LEVEL: " + str(current_evolve_level))


func _get_current_leafs() -> Array[EvolveLeaf]:
	current_leafs.clear()
	var branches : Array[EvolveBranch] = _get_all_possible_branches_for_evolve_level(current_evolve_level)
	
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


func _recursive_append_branches(_branch : EvolveBranch, found_branches : Array[EvolveBranch]) -> void:
	found_branches.append(_branch)
	
	if _branch.evolve_branches.is_empty():
		return
	
	for branch_branch in _branch.evolve_branches:
		_recursive_append_branches(branch_branch, found_branches)


func _get_all_possible_branches_for_evolve_level(_evolve_level : int) -> Array[EvolveBranch]:
	var possible_branches : Array[EvolveBranch]
	
	#get only branches with same evolve level and parent is visited
	for branch in all_branches:
		if branch.evolve_level == _evolve_level and branch.get_parent().is_visited:
			possible_branches.append(branch)
				
	return possible_branches
