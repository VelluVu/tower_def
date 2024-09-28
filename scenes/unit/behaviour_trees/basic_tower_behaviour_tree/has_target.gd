class_name HasTarget
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.has_target:
		return SUCCESS
	return FAILURE
