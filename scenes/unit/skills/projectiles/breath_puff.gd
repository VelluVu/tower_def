class_name BreathPuff
extends Node2D

## One puff of a Breather's breath (flame, frost mist, gas, a roar's dust): flies straight out from the mouth and
## plays its FLY animation once over its lifetime. Only for looks, the Breath skill does the hitting. Pooled by Breath.

const FLY_ANIMATION : StringName = &"FLY"

@onready var sprite : AnimatedSprite2D = $Sprite

var velocity : Vector2 = Vector2.ZERO
var life : float = 0.0
var age : float = 0.0

signal finished(puff : BreathPuff)


func launch(from : Vector2, new_velocity : Vector2, seconds : float) -> void:
	global_position = from
	velocity = new_velocity
	life = seconds
	age = 0.0
	show()
	var frames : SpriteFrames = sprite.sprite_frames
	sprite.flip_h = velocity.x < 0.0
	sprite.play(FLY_ANIMATION)
	#the whole animation over the puff's life, at any game speed
	sprite.speed_scale = frames.get_frame_count(FLY_ANIMATION) / (seconds * frames.get_animation_speed(FLY_ANIMATION)) * _time_scale()


func _process(delta : float) -> void:
	if not visible:
		return
	var time_scale : float = _time_scale()
	age += delta * time_scale
	position += velocity * delta * time_scale
	if age >= life:
		hide()
		sprite.stop()
		finished.emit(self)


func _time_scale() -> float:
	return Utils.game_control.time_scale if Utils.game_control != null else 1.0
