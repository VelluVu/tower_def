class_name StopMovement
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.linear_velocity = Vector2.ZERO
	if not actor.animated_sprite.is_playing():
		actor.animated_sprite.play(actor.IDLE_ANIMATION)
	return SUCCESS
