class_name IsBuildingDestroyed
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.closest_building == null:
		return SUCCESS
	return FAILURE
