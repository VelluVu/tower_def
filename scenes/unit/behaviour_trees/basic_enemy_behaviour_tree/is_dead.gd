class_name IsDead
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.stats_manager.stats.health <= 0:
		return SUCCESS
	return FAILURE
