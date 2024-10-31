class_name OvertimeEffect
extends Node


@onready var tick_timer : CustomTimer = $TickTimer

var tick_damage : float = 0.0
var tick_count : int = 0
var max_ticks : int = 0
var actor : Node = null

#for pool
signal damage_overtime_finished(overtime_effect : OvertimeEffect)


func start(_tick_damage : float, _actor : Node, ticks : int = 3, tick_interval : float = 1.0) -> void:
	tick_damage = _tick_damage
	actor = _actor
	max_ticks = ticks
	tick_timer.base_wait_time = tick_interval
	tick_timer.start()
	
	if not tick_timer.timeout.is_connected(_on_damage_tick):
		tick_timer.timeout.connect(_on_damage_tick)


func _on_damage_tick() -> void:
	if tick_count > max_ticks:
		tick_timer.stop()
		damage_overtime_finished.emit(self)
		return
		
	tick_count += 1
