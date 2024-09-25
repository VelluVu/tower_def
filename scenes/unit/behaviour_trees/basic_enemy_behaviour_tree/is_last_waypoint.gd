class_name IsLastWaypoint
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.current_waypoint_index >= actor.point_path.size():
		return SUCCESS
	return FAILURE
