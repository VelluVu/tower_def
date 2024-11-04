class_name OvertimeEffect
extends Node


@onready var tick_timer : CustomTimer = $TickTimer

var is_finished : bool = false
var is_reached_max_stack : bool = false
var tick_count : int = 0
var max_ticks : int = 0
var tick_damage : float = 0.0
var actor : Node = null
var source : Node = null
var damage_type : Utils.DamageType = Utils.DamageType.Normal
var effect_type : Utils.OvertimeEffectType = Utils.OvertimeEffectType.Tick

#for pool
signal damage_overtime_finished(overtime_effect : OvertimeEffect)


func start(overtime_effect_data : OvertimeEffectData, _actor : Node) -> void:
	actor = _actor
	source = overtime_effect_data.source
	tick_damage = overtime_effect_data.tick_damage
	damage_type = overtime_effect_data.damage_type
	max_ticks = overtime_effect_data.max_ticks
	effect_type = overtime_effect_data.effectType
	tick_timer.base_wait_time = overtime_effect_data.tick_interval
	is_finished = false
	tick_timer.start()
	
	if not tick_timer.timeout.is_connected(_on_damage_tick):
		tick_timer.timeout.connect(_on_damage_tick)


func add_stack(damage_tick : int) -> void:
	tick_count += 1
	
	if tick_count >= max_ticks:
		is_reached_max_stack = true
		
	tick_timer.stop()
	tick_damage += damage_tick
	tick_timer.start()


func _on_damage_tick() -> void:
	# handle different tick if stacking
	match(effect_type):
		Utils.OvertimeEffectType.Tick:
			if tick_count >= max_ticks:
				tick_timer.stop()
				is_finished = true
				damage_overtime_finished.emit(self)
			
		Utils.OvertimeEffectType.Stack:
			tick_timer.stop()
			is_finished = true
			damage_overtime_finished.emit(self)
			
	actor.take_damage(_create_damage_data())	
	tick_count += 1


func _create_damage_data() -> DamageData:
	var damage_data : DamageData = DamageData.new()
	damage_data.damage = tick_damage
	damage_data.damage_type = damage_type
	return damage_data
