class_name OvertimeEffect
extends Node


@onready var tick_timer : CustomTimer = $TickTimer

var is_finished : bool = false
var is_reached_max_stack : bool = false
var is_shielding : bool = false
var is_healing : bool = false
var tick_count : int = 0
var max_count : int = 0
var tick_damage : float = 0.0
var actor : Node = null
var source : Node = null
var damage_type : Utils.DamageType = Utils.DamageType.Normal
var effect_type : Utils.OvertimeEffectType = Utils.OvertimeEffectType.Tick
var effect_data : OvertimeEffectData = null
var added_modifier_datas : Array[ModifierData]

#for pool
signal damage_overtime_finished(overtime_effect : OvertimeEffect)


func start(overtime_effect_data : OvertimeEffectData, _actor : Node) -> void:
	actor = _actor
	effect_data = overtime_effect_data
	is_shielding = overtime_effect_data.is_shielding
	is_healing = overtime_effect_data.is_healing
	source = effect_data.source
	tick_damage = effect_data.tick_damage
	damage_type = effect_data.damage_type
	max_count = effect_data.max_count
	effect_type = effect_data.effectType
	tick_timer.base_wait_time = effect_data.tick_interval
	tick_count = 0
	is_finished = false
	is_reached_max_stack = false
	
	if effect_data.is_critical:
		add_extra_effects()
	add_extra_effects()
	
	tick_timer.start()
	
	if not tick_timer.timeout.is_connected(_on_damage_tick):
		tick_timer.timeout.connect(_on_damage_tick)


func stop() -> void:
	tick_timer.stop()
	is_finished = true
	is_reached_max_stack = true
	remove_extra_effects()
	damage_overtime_finished.emit(self)


func add_stack(overtime_effect_data : OvertimeEffectData) -> void:
	tick_count += 1
	
	if tick_count >= max_count:
		is_reached_max_stack = true
		
	tick_timer.stop()
	tick_damage += overtime_effect_data.tick_damage
	
	if overtime_effect_data.is_critical:
		add_extra_effects()
	add_extra_effects()
	
	tick_timer.start()


func add_extra_effects() -> void:
	if not effect_data.modifier_datas.is_empty():
		for modifier in effect_data.modifier_datas:
			actor.modifier_manager.add_modifier(modifier)
			added_modifier_datas.append(modifier)


func remove_extra_effects() -> void:
	if not added_modifier_datas.is_empty():
		for modifier in added_modifier_datas:
			actor.modifier_manager.remove_modifier(modifier)
	
	added_modifier_datas.clear()


func _on_damage_tick() -> void:
	if actor.is_dead:
		stop()
	
	# handle different tick if stacking
	match(effect_type):
		Utils.OvertimeEffectType.Tick:
			if max_count > 0 and tick_count >= max_count:
				stop()
			
		Utils.OvertimeEffectType.Stack:
			stop()
			
	actor.take_damage(_create_damage_data())	
	tick_count += 1


func _create_damage_data() -> DamageData:
	var damage_data : DamageData = DamageData.new()
	
	if source != null:
		damage_data.source = source
	
	damage_data.is_overtime = true
	damage_data.damage = tick_damage
	damage_data.damage_type = damage_type
	damage_data.is_shielding = is_shielding
	
	return damage_data
