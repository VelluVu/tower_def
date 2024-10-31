class_name Dead
extends ActionLeaf

var is_dead : bool = false

func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.stats_manager.stats.health > 0:
		is_dead = false
		return FAILURE
	
	if not is_dead:
		is_dead = true
		actor.die()
	
	return RUNNING
