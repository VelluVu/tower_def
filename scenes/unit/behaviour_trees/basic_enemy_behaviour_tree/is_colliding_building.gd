class_name IsCollidingBuilding
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.is_colliding_building:
		return SUCCESS
	else:
		return FAILURE
