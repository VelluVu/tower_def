class_name IsBuildingInNextWaypoint
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.level.has_building_in_world_position(actor.next_waypoint):
		return SUCCESS
	return FAILURE
