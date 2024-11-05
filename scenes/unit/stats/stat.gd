class_name Stat
extends Node


@export var base_value : float = 0
@export var value : float = 0 :
	set = _set_value
@export var type : Utils.StatType = Utils.StatType.Health
var flat_modifiers : Array[Modifier]
var multiply_modifiers : Array[Modifier]

signal changed(stat : Stat)


func _ready() -> void:
	name = str(Utils.StatType.keys()[type])


func add_modifier(modifier : Modifier) -> void:
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
			modified_value += modified_value * mod.value
	
	value = modified_value


func remove_modifier(modifier : Modifier) -> void:
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
			modified_value += modified_value * mod.value
	
	value = modified_value


func reset_stat_value() -> void:
	value = base_value


func _set_value(new_value : float) -> void:
	if value == new_value:
		return
	
	value = new_value
	changed.emit(self)
