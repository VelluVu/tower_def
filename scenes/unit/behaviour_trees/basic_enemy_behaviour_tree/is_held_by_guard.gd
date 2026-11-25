@tool
class_name IsHeldByGuard
extends ConditionLeaf

## A Hatchery guard holds the actor (Enemy.held_by): it stops and fights the guard instead of walking on.


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if is_instance_valid(actor.held_by):
		return SUCCESS
	return FAILURE
