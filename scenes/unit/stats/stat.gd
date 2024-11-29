class_name Stat
extends Node


@export var base_value : float = 0.0
@export var value : float = 0.0 :
	get = _get_value,
	set = _set_value
@export var type : Utils.StatType = Utils.StatType.Health

var flat_modifiers : Array[ModifierData]
var multiply_modifiers : Array[ModifierData]

signal changed(stat : Stat)


func _ready() -> void:
	name = str(Utils.StatType.keys()[type])


func add_modifier_data(modifier : ModifierData) -> void:
	match modifier.type:
		Utils.ModifyType.Flat:
			flat_modifiers.append(modifier)
		Utils.ModifyType.Multiply:
			multiply_modifiers.append(modifier)
	
	var modified_value : float = base_value
	
	if not flat_modifiers.is_empty():
		for mod in flat_modifiers:
			modified_value += mod.value
	
	if not multiply_modifiers.is_empty():
		for mod in multiply_modifiers:
			if modified_value != 0.0:
				modified_value *= (1.0 + mod.value)
			else:
				modified_value += mod.value
	
	#limit speed
	if type == Utils.StatType.Speed:
		var minimum_value : float = base_value * 0.1
		modified_value = modified_value if modified_value >= minimum_value else minimum_value
	
	print(name, " modified value: ", modified_value)
	value = modified_value


func remove_modifier_data(modifier : ModifierData) -> void:
	match modifier.type:
		Utils.ModifyType.Flat:
			flat_modifiers.erase(modifier)
		Utils.ModifyType.Multiply:
			multiply_modifiers.erase(modifier)
	
	var modified_value : float = base_value
	
	if not flat_modifiers.is_empty():
		for mod in flat_modifiers:
			modified_value += mod.value
	
	if not multiply_modifiers.is_empty():
		for mod in multiply_modifiers:
			if modified_value != 0.0:
				modified_value *= (1.0 + mod.value)
			else:
				modified_value += mod.value
	
	#limit speed
	if type == Utils.StatType.Speed:
		var minimum_value : float = base_value * 0.1
		modified_value = modified_value if modified_value >= minimum_value else minimum_value
	
	value = modified_value


func reset_stat_value() -> void:
	value = base_value


func _get_value() -> float:
	return value


func _set_value(new_value : float) -> void:
	if value == new_value:
		return
	
	value = new_value
	changed.emit(self)
