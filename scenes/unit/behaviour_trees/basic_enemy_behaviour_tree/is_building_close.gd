class_name IsBuildingClose
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.closest_building = null
	actor._get_closest_building()
	if actor.closest_building != null:
		return SUCCESS
	return FAILURE
