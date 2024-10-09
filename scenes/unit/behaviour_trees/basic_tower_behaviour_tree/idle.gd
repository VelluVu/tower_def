class_name Idle
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animated_sprite.animation != actor.IDLE_ANIMATION:
		actor.animated_sprite.play(actor.IDLE_ANIMATION)
		return SUCCESS
	else:
		if not actor.animated_sprite.is_playing():
			actor.animated_sprite.play(actor.IDLE_ANIMATION)
		
	return SUCCESS
