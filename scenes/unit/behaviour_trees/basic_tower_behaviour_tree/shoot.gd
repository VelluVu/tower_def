class_name Shoot
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.skill.use(actor.get_first_target(), actor.stats_manager.stats.damage)
	return SUCCESS
