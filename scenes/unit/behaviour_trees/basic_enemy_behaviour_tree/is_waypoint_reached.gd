class_name IsWaypointReached
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.global_position.distance_to(actor.next_waypoint) < actor.minimum_distance_to_next_waypoint:
		return SUCCESS
	return FAILURE
