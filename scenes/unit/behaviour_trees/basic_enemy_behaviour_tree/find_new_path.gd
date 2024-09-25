class_name FindNewPath
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.point_path = actor.level.find_path(actor.global_position, actor.end_point.global_position)
	actor.current_waypoint_index = 0
	actor.next_waypoint = actor.point_path[actor.current_waypoint_index]
	if actor.point_path.is_empty():
		return SUCCESS
	else:
		return FAILURE
