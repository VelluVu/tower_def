class_name IsAttacking
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animated_sprite.animation == actor.ATTACK_ANIMATION and actor.animated_sprite.is_playing():
		return SUCCESS
	return FAILURE
