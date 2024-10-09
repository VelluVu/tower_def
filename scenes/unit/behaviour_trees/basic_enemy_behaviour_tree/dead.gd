class_name Dead
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.stats_manager.stats.health > 0:
		return FAILURE
		
	actor.die()
	return RUNNING
