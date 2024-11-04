class_name DamageData
extends Node


@export var damage : int = 1
@export var critical_chance : float = 0.05
@export var critical_multiplier : float = 2.0
@export var damage_type : Utils.DamageType
@export var overtime_effect_datas : Array[OvertimeEffectData] :
	get:
		if overtime_effect_datas.is_empty():
			for child in get_children():
				if child is OvertimeEffectData:
					if overtime_effect_datas.has(child):
						continue
					overtime_effect_datas.append(child)
		return overtime_effect_datas

var is_critical : bool
var source : Node = null :
	set = _set_source


func calculate_critical() -> void:
	is_critical = randf() < critical_chance
	damage = round(critical_multiplier * damage) if is_critical else damage


func _set_source(new_source : Node) -> void:
	if source == new_source:
		return
	
	source = new_source
	
	if overtime_effect_datas.is_empty():
		return
	
	for effect in overtime_effect_datas:
		effect.source = source
