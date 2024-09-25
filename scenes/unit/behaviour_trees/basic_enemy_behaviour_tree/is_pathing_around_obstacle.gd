class_name IsPathingAroundObstacle
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.is_pathing_around_obstacle:
		return SUCCESS
	return FAILURE
