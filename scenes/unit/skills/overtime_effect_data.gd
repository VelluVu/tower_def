class_name OvertimeEffectData
extends Node


@export var max_count : int = 3
@export var tick_damage : float = 1.0
@export var tick_interval : float = 1.0
@export var chance_to_apply : float = 1.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Normal
@export var effectType : Utils.OvertimeEffectType = Utils.OvertimeEffectType.Tick
@export var is_healing : bool = false
@export var is_shielding : bool = false

var modifier_datas : Array[ModifierData] :
	get:
		if is_serialized_modifiers_added:
			return modifier_datas
		
		for modifier in modifiers:
			var data : ModifierData = ModifierData.new(modifier)
			modifier_datas.append(data)
			added_serialized_modifiers_datas.append(data)
		
		is_serialized_modifiers_added = true
		return modifier_datas

var modifiers : Array[Modifier] :
	get:
		for child in get_children():
			if child is Modifier:
				if modifiers.has(child):
					continue
				modifiers.append(child)
		return modifiers

var is_serialized_modifiers_added : bool = false :
	set(value):
		if value == is_serialized_modifiers_added:
			return
		
		is_serialized_modifiers_added = value
		
		if is_serialized_modifiers_added == false:
			if added_serialized_modifiers_datas.is_empty():
				return
				
			if modifier_datas.is_empty():
				return
				
			for data in added_serialized_modifiers_datas:
				if modifier_datas.has(data):
					modifier_datas.erase(data)

var is_critical : bool = false
var source : Node = null
var added_serialized_modifiers_datas : Array[ModifierData]


#turn back off when new serialized modifiers are added
