class_name DamageData
extends Node


@export var damage_type : Utils.DamageType = Utils.DamageType.Normal

var is_overtime : bool = false
var is_shielding : bool = false
var is_critical : bool = false

var is_healing : bool = false :
	get:
		return true if damage < 0.0 else false 

var damage : float = 0.0 :
	set(value):
		if damage == value:
			return
		damage = snappedf(value, 0.01)
		rounded_damage = damage

var rounded_damage : float = 0.0 :
	set(value):
		if rounded_damage == value:
			return
		
		rounded_damage = round(value)

var source : Node = null :
	set = _set_source
	
var overtime_effect_datas : Array[OvertimeEffectData] :
	get:
		if overtime_effect_datas.is_empty():
			for child in get_children():
				if child is OvertimeEffectData:
					if overtime_effect_datas.has(child):
						continue
					overtime_effect_datas.append(child)
		return overtime_effect_datas

var modifiers : Array[Modifier] :
	get:
		for child in get_children():
			if child is Modifier:
				if modifiers.has(child):
					continue
				modifiers.append(child)
		return modifiers


func _set_source(new_source : Node) -> void:
	if source == new_source:
		return
	
	source = new_source
	
	if overtime_effect_datas.is_empty():
		return
	
	for effect in overtime_effect_datas:
		effect.source = source
