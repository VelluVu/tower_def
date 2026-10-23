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
var additive_modifiers : Array[ModifierData]
var global_additive_modifiers : Array[ModifierData]

var has_modifiers : bool = false : 
	get:
		return not flat_modifiers.is_empty() or not multiply_modifiers.is_empty() or not additive_modifiers.is_empty() or not global_flat_modifiers.is_empty() or not global_multiply_modifiers.is_empty() or not global_additive_modifiers.is_empty()
		

signal changed(stat : Stat)


func _ready() -> void:
	name = str(Utils.StatType.keys()[type])


func add_modifier(modifier : ModifierData) -> void:
	_get_modifier_list(modifier).append(modifier)


func remove_modifier(modifier : ModifierData) -> void:
	_get_modifier_list(modifier).erase(modifier)


func _get_modifier_list(modifier : ModifierData) -> Array[ModifierData]:
	var is_global : bool = modifier.modifier_type == Utils.ModifierType.GlobalModifier

	match modifier.calculate_type:
		Utils.ModifyType.Flat:
			return global_flat_modifiers if is_global else flat_modifiers
		Utils.ModifyType.Additive:
			return global_additive_modifiers if is_global else additive_modifiers

	return global_multiply_modifiers if is_global else multiply_modifiers


func reset_stat_value() -> void:
	value = base_value


func _get_value() -> float:
	return value


func _set_value(new_value : float) -> void:
	if value == new_value:
		return
	
	value = new_value
	changed.emit(self)
