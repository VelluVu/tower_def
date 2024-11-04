class_name OvertimeEffectHandler
extends Node


const overtime_effect_scene : PackedScene = preload("res://scenes/unit/skills/overtime_effect.tscn")

class OvertimeEffectStack:
	var stack : Array[OvertimeEffect]
	var damage_type : Utils.DamageType = Utils.DamageType.Normal : 
		get:
			if stack.is_empty():
				return damage_type
			return stack[0].damage_type

@export var actor : Node = null :
	get:
		if actor == null:
			actor = get_parent()
		return actor

var pool : Array[OvertimeEffect]


func handle_overtime_effects(overtime_effect_datas : Array[OvertimeEffectData]) -> void:
	if overtime_effect_datas.is_empty():
		return
		
	for overtime_effect in overtime_effect_datas:
		if overtime_effect.chance_to_apply >= 1.0:
			add_overtime_effect(overtime_effect)
			continue
		if randf() < overtime_effect.chance_to_apply:
			add_overtime_effect(overtime_effect)


func add_overtime_effect(overtime_effect_data : OvertimeEffectData) -> void:
	# see if stack,
	if overtime_effect_data.effectType == Utils.OvertimeEffectType.Stack:
		# then find the previous overtime from source
		for child in get_children():
			#if child is not active
			if child.is_finished or child.is_reached_max_stack:
				continue
				
			# if there is previous overtime stack, 
			if child.source == overtime_effect_data.source and child.damage_type == overtime_effect_data.damage_type:
				# reset timer instead creating new and add damage to overtime
				child.add_stack(overtime_effect_data.tick_damage)
				#leave function since we added the stack into existing timer
				return
	
	var overtime_effect : OvertimeEffect = _get_overtime_effect()
	overtime_effect.start(overtime_effect_data, actor)


func _get_overtime_effect() -> OvertimeEffect:
	var effect : OvertimeEffect = overtime_effect_scene.instantiate() if pool.is_empty() else pool.pop_back()
	
	if effect.get_parent() == null:
		add_child(effect)
		
	if not effect.damage_overtime_finished.is_connected(_on_overtime_effect_finished):
		effect.damage_overtime_finished.connect(_on_overtime_effect_finished)
	
	return effect


func _on_overtime_effect_finished(overtime_effect : OvertimeEffect) -> void:
	pool.push_back(overtime_effect)
