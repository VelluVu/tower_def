class_name AnimationControl
extends AnimatedSprite2D


#stored time scale values
var is_time_altered : bool = false :
	get:
		return current_time_scale != 1.0
var current_time_scale : float = 1.0

#the wanted animation duration in seconds, 0.0 == original animation length
var current_wanted_playtime : float = 0.0


func _ready() -> void:
	#event from game control, when the time scale is changed
	if not GameSignals.time_scale_change.is_connected(_on_time_scale_change):
		GameSignals.time_scale_change.is_connected(_on_time_scale_change)
	
	#check the current time scale when this object is ready
	_on_time_scale_change(Utils.game_control.time_scale)


func play_animation(animation_name : String, wanted_play_time : float = 0.0) -> void:
	current_wanted_playtime = wanted_play_time
	
	#if looping animation is ongoing, then only alter the animation speed
	if animation == animation_name:
		if sprite_frames.get_animation_loop(animation_name):
			if is_playing():
				_alter_current_animation_speed()
				return
	
	#one shot animation is started before altering
	play(animation_name)
	_alter_current_animation_speed()


func _alter_current_animation_speed() -> void:
	if not is_playing():
		return
	
	#if wanted play time is 0.0 we keep the time scale as it is
	if current_wanted_playtime <= 0.0:
		speed_scale = Utils.game_control.time_scale
		return
	
	var frames_count : int = sprite_frames.get_frame_count(animation)
	var animation_duration : float = 0
	var animation_fps : float = sprite_frames.get_animation_speed(animation)
	var current_playing_speed : float = abs(get_playing_speed())
	
	for n in range(frames_count):
		var absolute_frame_duration : float = sprite_frames.get_frame_duration(animation, n) / (animation_fps * current_playing_speed)
		animation_duration += absolute_frame_duration
		
	var scaler : float = 1 / (current_wanted_playtime / animation_duration)
	speed_scale = scaler * current_time_scale if scaler != 1.0 else speed_scale


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	_alter_current_animation_speed()
