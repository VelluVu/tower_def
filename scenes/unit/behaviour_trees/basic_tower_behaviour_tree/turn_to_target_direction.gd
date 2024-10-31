class_name TurnToTargetDirection
extends ActionLeaf


func tick(actor : Node, _blackBoard : Blackboard) -> int:
	if actor.target == null:
		return FAILURE
	
	# direction normalized vector to target, 
	# then check if x component value is negative
	# flip horizontal is set to above condition
	actor.animation_control.flip_h = ((actor.target.global_position - actor.global_position).normalized().x < 0.0)
	
	return SUCCESS
