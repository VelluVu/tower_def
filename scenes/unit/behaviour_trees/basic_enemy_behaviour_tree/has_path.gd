class_name HasPath
extends ConditionLeaf


func tick(actor: Node, _blackboard: Blackboard) -> int:
	if actor.has_path:
		return SUCCESS
	else:
		return FAILURE
	
