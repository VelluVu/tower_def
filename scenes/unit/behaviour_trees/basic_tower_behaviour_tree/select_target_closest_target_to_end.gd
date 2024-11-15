class_name SelectClosestTargetToEnd
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var new_target = actor.get_closest_target_to_end()
	actor.target = new_target
	return SUCCESS
