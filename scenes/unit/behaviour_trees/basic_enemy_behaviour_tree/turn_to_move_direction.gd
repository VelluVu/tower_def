class_name TurnToMoveDirection
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.animation_control.flip_h = actor.linear_velocity.x <= 0
	return SUCCESS
