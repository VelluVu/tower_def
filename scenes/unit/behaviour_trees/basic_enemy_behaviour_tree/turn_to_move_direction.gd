class_name TurnToMoveDirection
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.look_at(actor.global_position + actor.global_position.direction_to(actor.next_waypoint))
	return SUCCESS
