@tool
class_name AttackGuard
extends ActionLeaf

## Hits back at the Hatchery guard holding the actor whenever its attack is ready (not while numb, Frostplague).
## Always a success, so the tree does not walk on while it is held.


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var guard = actor.held_by
	if not is_instance_valid(guard) or guard.is_dead:
		return SUCCESS
	if actor.skill.is_ready and not actor.is_numb:
		actor.skill.use(guard)
	return SUCCESS
