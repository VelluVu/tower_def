class_name TurnToMoveDirection
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.animated_sprite.flip_h = actor.linear_velocity.x <= 0
	return SUCCESS
