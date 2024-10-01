class_name IsMoving
extends ConditionLeaf


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var last_position_magnitude_to_current : float = (actor.global_position - actor.last_position).length()
	if actor.linear_velocity.length() >= 0.01 and last_position_magnitude_to_current > 0.0:
		return SUCCESS
	return FAILURE
