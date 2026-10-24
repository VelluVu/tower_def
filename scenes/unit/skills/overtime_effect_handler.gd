class_name OvertimeEffectHandler
extends Node


const overtime_effect_scene : PackedScene = preload("res://scenes/unit/skills/overtime_effect.tscn")

@export var actor : Node = null :
	get:
		if actor == null:
			actor = get_parent()
		return actor

var pool : Array[OvertimeEffect]
#Thermal Shock: every effect on this unit ticks this much faster
var tick_rate_bonus : float = 0.0 :
	set = _set_tick_rate_bonus
var start_overtime_effect_datas : Array[OvertimeEffectData]


func handle_start_overtime_effects(value : float) -> void:
	#rebuilt on every call: a reactivated enemy must not get its regeneration twice
	start_overtime_effect_datas.clear()
	for child in get_children():
		if child is OvertimeEffectData:
			start_overtime_effect_datas.append(child)
	
	handle_overtime_effects(start_overtime_effect_datas, value)


func handle_overtime_effects(overtime_effect_datas : Array[OvertimeEffectData], value : float) -> void:
	if overtime_effect_datas.is_empty():
		return
		
	for overtime_effect_data in overtime_effect_datas:
		var chance : float = overtime_effect_data.get_chance()
		if chance >= 1.0 or randf() < chance:
			add_overtime_effect(overtime_effect_data, value)


func add_overtime_effect(overtime_effect_data : OvertimeEffectData, value : float) -> void:
	#worked out per application, the data can be shared (start effects), so it is never written to
	var tick_damage : float = overtime_effect_data.get_tick_damage(value)
	
	if overtime_effect_data.effectType == Utils.OvertimeEffectType.Stack:
		var stacks : Array[OvertimeEffect] = get_active_stacks(overtime_effect_data.damage_type)
		
		#at the cap the new stack replaces the weakest one, if it is at least as strong
		if stacks.size() >= overtime_effect_data.get_max_stacks():
			var weakest : OvertimeEffect = get_weakest_stack(stacks)
			if weakest == null or weakest.compare_strength(tick_damage, overtime_effect_data.potency) > 0:
				return
			weakest.stop()
	
	var overtime_effect : OvertimeEffect = _get_overtime_effect()
	overtime_effect.start(overtime_effect_data, actor, tick_damage)
	
	if tick_rate_bonus > 0.0:
		overtime_effect.set_tick_speed(1.0 + tick_rate_bonus)


## The running element stacks of one damage type on this unit, whichever tower put them there.
func get_active_stacks(damage_type : Utils.DamageType) -> Array[OvertimeEffect]:
	var stacks : Array[OvertimeEffect] = []
	
	for child in get_children():
		if child is OvertimeEffect and not child.is_finished and child.effect_type == Utils.OvertimeEffectType.Stack and child.damage_type == damage_type:
			stacks.append(child)
	
	return stacks


## The weakest stack; of equally strong ones, the one closest to ending.
static func get_weakest_stack(stacks : Array[OvertimeEffect]) -> OvertimeEffect:
	var weakest : OvertimeEffect = null
	
	for stack in stacks:
		if weakest == null:
			weakest = stack
			continue
		
		var strength : int = stack.compare_strength(weakest.tick_damage, weakest.potency)
		if strength < 0 or (strength == 0 and stack.tick_count > weakest.tick_count):
			weakest = stack
	
	return weakest


func _get_overtime_effect() -> OvertimeEffect:
	var effect : OvertimeEffect = overtime_effect_scene.instantiate() if pool.is_empty() else pool.pop_back()
	
	if effect.get_parent() == null:
		effect.name = effect.name + str(get_child_count())
		add_child(effect)
		
	if not effect.damage_overtime_finished.is_connected(_on_overtime_effect_finished):
		effect.damage_overtime_finished.connect(_on_overtime_effect_finished)
	
	return effect


func clear_overtime_effects() -> void:
	for child in get_children():
		if child is OvertimeEffect:
			child.stop()
			child.queue_free()
	
	pool.clear()


func _set_tick_rate_bonus(value : float) -> void:
	if is_equal_approx(tick_rate_bonus, value):
		return
	
	tick_rate_bonus = value
	
	for child in get_children():
		if child is OvertimeEffect and not child.is_finished:
			child.set_tick_speed(1.0 + tick_rate_bonus)


func _on_overtime_effect_finished(overtime_effect : OvertimeEffect) -> void:
	pool.push_back(overtime_effect)
