class_name AnimationControl
extends AnimatedSprite2D


func play_animation(animation_name : String, active_time : float) -> void:
	var frames_count = sprite_frames.get_frame_count(animation_name)
	var animation_total_duration : float = 0
	
	for n in range(frames_count):
		var duration : float = sprite_frames.get_frame_duration(animation_name, n)
		animation_total_duration += duration
		
	print(name, " frame count ", frames_count)
	print(name, " total duration ", animation_total_duration)
	print(name, " active skill time ", active_time)
	
	
	play(animation_name)
