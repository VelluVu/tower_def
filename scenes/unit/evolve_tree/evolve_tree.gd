class_name EvolveTree
extends Node


@onready var actor : Node = get_parent()

@export var current_evolve_level : int = -1 :
	set = _set_current_evolve_level

@export var first_evolve_level_xp_reguirement : float = 10.0

var is_current_evolve_option_selected : bool = false
var available_evolve_level : int = -1
var is_visited : bool = true
var next_evolve_xp_reguirement : float :
	get:
		var evolve_level_multiplier : float = float(available_evolve_level) + 2.0
		next_evolve_xp_reguirement = first_evolve_level_xp_reguirement * evolve_level_multiplier
		print(actor.name, " gained " ,str(next_evolve_xp_reguirement), " evolve XP")
		return next_evolve_xp_reguirement
		
var evolve_xp : float = 0.0 :
	set = _set_evolve_xp
var current_leafs : Array[EvolveLeaf]

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


func _set_evolve_xp(value : float) -> void:
	if value <= 0.0:
		return
	
	evolve_xp = value
	
	if evolve_xp >= next_evolve_xp_reguirement:
		evolve_xp = evolve_xp - next_evolve_xp_reguirement
		available_evolve_level += 1
		
		#what if not selected current evolve option
		if is_current_evolve_option_selected:
			current_evolve_level += 1
		
		evolve_level_gained.emit()


func _ready() -> void:
	available_evolve_level = current_evolve_level
	is_current_evolve_option_selected = true
	current_leafs = _get_current_leafs()
	UISignals.upgrade_option_selected.connect(_on_upgrade_option_selected)


func _on_upgrade_option_selected(_index : int, _building_id : int) -> void:
	if actor.id != _building_id:
		return
	
	current_leafs[_index].evolve(actor)
	is_current_evolve_option_selected = true
	
	if current_evolve_level <= available_evolve_level:
		current_evolve_level += 1
	
	evolved.emit()


func _set_current_evolve_level(_evolve_level : int) -> void:
	if _evolve_level == current_evolve_level:
		return
	
	is_current_evolve_option_selected = false
	current_evolve_level = _evolve_level
	current_leafs = _get_current_leafs()
	evolve_level_changed.emit()
	print(actor.name, " GAINED NEW EVOLVE LEVEL: " + str(current_evolve_level))


func _get_current_leafs() -> Array[EvolveLeaf]:
	current_leafs.clear()
	var branches : Array[EvolveBranch] = get_all_possible_branches_for_evolve_level(current_evolve_level)
	
	for branch in branches:
		for leaf in branch.evolve_leafs:
			current_leafs.append(leaf)
			
	return current_leafs


func get_all_possible_branches_for_evolve_level(_evolve_level : int) -> Array[EvolveBranch]:
	var possible_branches : Array[EvolveBranch]
	
	#get only branches with same evolve level and parent is visited
	for child in get_children(true):
		if child is EvolveBranch:
			if child.evolve_level == _evolve_level and child.get_parent().is_visited:
				possible_branches.append(child)
				
	return possible_branches
