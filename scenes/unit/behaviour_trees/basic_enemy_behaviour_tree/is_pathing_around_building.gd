class_name IsPathingAroundBuilding
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.is_pathing_around_building:
		return SUCCESS
	return FAILURE
