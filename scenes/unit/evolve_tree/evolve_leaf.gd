class_name EvolveLeaf
extends Node


@export var icon : Texture2D
@export var info : String


func evolve(_actor : Node) -> void:
	get_parent().is_visited = true
