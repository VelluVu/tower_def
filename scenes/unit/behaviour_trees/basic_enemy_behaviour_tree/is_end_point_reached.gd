class_name IsEndPointReached
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.global_position.distance_to(actor.end_point.global_position) < actor.minimum_distance_to_end:
		return SUCCESS
	return FAILURE
