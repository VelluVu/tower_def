class_name TalentBook
extends Resource

## Every talent tree, in tab order.

@export var trees : Array[TalentTree] = []


func get_tree_by_id(tree_id : StringName) -> TalentTree:
	for tree in trees:
		if tree.id == tree_id:
			return tree

	return null
