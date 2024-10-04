class_name IterateNextWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var index : int = actor.current_waypoint_index
	actor.iterate_next_waypoint()
	if actor.current_waypoint_index == index:
		return FAILURE
	return SUCCESS
