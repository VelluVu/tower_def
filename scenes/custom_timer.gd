class_name CustomTimer
extends Timer

#updates time scale!
var base_wait_time : float = 0.0 :
	set(value):
		if value < 0.0:
			return
			
		base_wait_time = value
		
		if value <= 0.0:
			return
		
		wait_time = base_wait_time / Utils.game_control.time_scale
		#print(name, " base wait time is set to: ", base_wait_time)


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
