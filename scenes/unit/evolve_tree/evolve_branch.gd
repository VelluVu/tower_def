class_name EvolveBranch
extends Node


@export var evolve_level : int
var is_visited : bool = false


@onready var evolve_leafs : Array[EvolveLeaf] :
	get:
		for child in get_children():
			if child is EvolveLeaf:
				evolve_leafs.append(child)
		return evolve_leafs


@onready var evolve_branches : Array[EvolveBranch] :
	get:
		for child in get_children():
			if child is EvolveBranch:
				evolve_branches.append(child)
		return evolve_branches
