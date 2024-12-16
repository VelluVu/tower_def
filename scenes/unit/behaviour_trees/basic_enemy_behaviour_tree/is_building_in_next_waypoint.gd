class_name IsBuildingInNextWaypoint
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var building : Building = actor.get_building_in_next_waypoint()
	
	if building != null:
		return SUCCESS
	return FAILURE
