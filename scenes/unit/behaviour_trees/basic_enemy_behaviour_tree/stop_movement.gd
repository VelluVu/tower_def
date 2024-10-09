class_name StopMovement
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.linear_velocity = Vector2.ZERO
	return SUCCESS
