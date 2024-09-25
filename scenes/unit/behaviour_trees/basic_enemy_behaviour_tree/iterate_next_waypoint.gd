class_name IterateNextWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.current_waypoint_index += 1
	if actor.current_waypoint_index >= actor.point_path.size():
		return FAILURE
	actor.next_waypoint = actor.point_path[actor.current_waypoint_index]
	return SUCCESS
