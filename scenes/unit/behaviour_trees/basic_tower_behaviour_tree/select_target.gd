class_name SelectTarget
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.target = actor.get_closest_target_to_end()
	if actor.target != null:
		return SUCCESS
	return FAILURE
