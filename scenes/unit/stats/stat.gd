class_name Stat
extends Node


@export var base_value : float = 0.0
@export var value : float = 0.0 :
	get = _get_value,
	set = _set_value
@export var type : Utils.StatType = Utils.StatType.Health

var flat_modifiers : Array[ModifierData]
var multiply_modifiers : Array[ModifierData]
var global_flat_modifiers : Array[ModifierData]
var global_multiply_modifiers :Array[ModifierData]

var has_modifiers : bool = false : 
	get:
		return not flat_modifiers.is_empty() or not multiply_modifiers.is_empty() or not global_flat_modifiers.is_empty() or not global_multiply_modifiers.is_empty()
		

signal changed(stat : Stat)


func _ready() -> void:
	name = str(Utils.StatType.keys()[type])


func add_modifier(modifier : ModifierData) -> void:
	match modifier.modifier_type:
		Utils.ModifyType.Flat:
			if modifier.modifier_type == Utils.ModifierType.GlobalModifier:
				global_flat_modifiers.append(modifier)
			else:
				flat_modifiers.append(modifier)
		Utils.ModifyType.Multiply:
			if modifier.modifier_type == Utils.ModifierType.GlobalModifier:
				global_multiply_modifiers.append(modifier)
			else:
				multiply_modifiers.append(modifier)


func remove_modifier(modifier : ModifierData) -> void:
	match modifier.modifier_type:
		Utils.ModifyType.Flat:
			if modifier.modifier_type == Utils.ModifierType.GlobalModifier:
				global_flat_modifiers.erase(modifier)
			else:
				flat_modifiers.erase(modifier)
		Utils.ModifyType.Multiply:
			if modifier.modifier_type == Utils.ModifierType.GlobalModifier:
				global_multiply_modifiers.erase(modifier)
			else:
				multiply_modifiers.erase(modifier)


func reset_stat_value() -> void:
	value = base_value


func _get_value() -> float:
	return value


func _set_value(new_value : float) -> void:
	if value == new_value:
		return
	
	value = new_value
	changed.emit(self)
