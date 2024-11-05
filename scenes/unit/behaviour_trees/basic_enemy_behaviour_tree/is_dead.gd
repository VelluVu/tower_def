class_name IsDead
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.is_dead:
		return SUCCESS
	return FAILURE
