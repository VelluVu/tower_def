class_name StopMovement
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.linear_velocity = Vector2.ZERO
	if actor.animated_sprite.animation == actor.IDLE_ANIMATION:
		if not actor.animated_sprite.is_playing():
			actor.animated_sprite.play(actor.IDLE_ANIMATION)
	if actor.animated_sprite.animation == actor.WALK_ANIMATION:
		actor.animated_sprite.play(actor.IDLE_ANIMATION)
	return SUCCESS
