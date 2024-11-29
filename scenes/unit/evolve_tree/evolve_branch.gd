class_name EvolveBranch
extends Node


@onready var evolve_leafs : Array[EvolveLeaf] :
	get:
		if not evolve_leafs.is_empty():
			return evolve_leafs
			
		for child in get_children():
			if child is EvolveLeaf:
				evolve_leafs.append(child)
		return evolve_leafs


@onready var evolve_branches : Array[EvolveBranch] :
	get:
		if not evolve_branches.is_empty():
			return evolve_branches
			
		for child in get_children():
			if child is EvolveBranch:
				evolve_branches.append(child)
		return evolve_branches

@export var evolve_level : int

var is_visited : bool = false
