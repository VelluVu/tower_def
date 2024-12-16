class_name CustomTimer
extends Timer

#set this only in ready or inspector
var unscaled_base_value : float = 0.0 :
	set(value):
		if value < 0.0:
			return
		
		unscaled_base_value = value
		base_wait_time = value

#updates time scale!
var base_wait_time : float = 0.0 :
	set(value):
		if value < 0.0:
			return
			
		base_wait_time = value
		
		if base_wait_time <= 0.0:
			return
		
		wait_time = base_wait_time / Utils.game_control.time_scale
		#print(name, " base wait time is set to: ", base_wait_time)


func scale_wait_time(stat_value : float) -> void:
	print(name, " ", stat_value)
	base_wait_time = unscaled_base_value * (1 / (1.0 + stat_value))


func _ready() -> void:
	GameSignals.time_scale_change.connect(_on_time_scale_change)


func alter_time_left() -> void:
	if time_left <= 0.0:
		return
		
	var timer_time_left : float = time_left
	stop()
	timer_time_left = timer_time_left / Utils.game_control.time_scale
	start(timer_time_left)


func _on_time_scale_change(new_time_scale : float) -> void:
	alter_time_left()
	
	if base_wait_time <= 0.0:
		return

	wait_time = base_wait_time / new_time_scale
