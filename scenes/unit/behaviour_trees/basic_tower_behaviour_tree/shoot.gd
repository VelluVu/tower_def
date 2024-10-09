class_name Shoot
extends ActionLeaf

@export var frame_to_use_skill : int = 4
var has_attacked : bool = false


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animated_sprite.animation != actor.ATTACK_ANIMATION:
		has_attacked = false
		actor.animated_sprite.play(actor.ATTACK_ANIMATION)
	
	if actor.animated_sprite.animation == actor.ATTACK_ANIMATION:
		if actor.animated_sprite.is_playing() and actor.animated_sprite.frame == frame_to_use_skill and !has_attacked:
			has_attacked = true
			actor.skill.use(actor.get_first_target(), actor.stats_manager.stats.damage)
			return SUCCESS
		else:
			if not actor.animated_sprite.is_playing():
				actor.animated_sprite.play(actor.ATTACK_ANIMATION)
				has_attacked = false
			return RUNNING
			
	return FAILURE
