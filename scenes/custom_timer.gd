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


#the game speed the running countdown was scaled for
var current_time_scale : float = 1.0


# a higher stat value shortens the wait (attack speed)
func scale_wait_time(stat_value : float) -> void:
	base_wait_time = unscaled_base_value * (1 / (1.0 + stat_value))


# a higher stat value lengthens the wait (active duration)
func extend_wait_time(stat_value : float) -> void:
	base_wait_time = unscaled_base_value * (1.0 + stat_value)


func _ready() -> void:
	if Utils.game_control != null:
		current_time_scale = Utils.game_control.time_scale

	GameSignals.time_scale_change.connect(_on_time_scale_change)


func alter_time_left(new_time_scale : float) -> void:
	var old_time_scale : float = current_time_scale
	current_time_scale = new_time_scale

	if time_left <= 0.0:
		return

	var timer_time_left : float = time_left * old_time_scale / new_time_scale
	stop()
	start(timer_time_left)


func _on_time_scale_change(new_time_scale : float) -> void:
	alter_time_left(new_time_scale)

	if base_wait_time <= 0.0:
		return

	wait_time = base_wait_time / new_time_scale
