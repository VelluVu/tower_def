class_name TurnToTargetDirection
extends ActionLeaf


func tick(actor : Node, _blackBoard : Blackboard) -> int:
	if actor.target == null:
		return FAILURE
	
	# direction normalized vector to target, 
	# then check if x component value is negative
	# flip horizontal is set to above condition
	var target_direction : Vector2 = (actor.target.global_position - actor.global_position).normalized()
	actor.animation_control.flip(target_direction)
	actor.skill.flip_h = actor.animation_control.flip_h
	return SUCCESS
