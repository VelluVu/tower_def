class_name OvertimeEffectData
extends Node


@export var max_count : int = 3
@export var tick_damage : float = 1.0
@export var tick_interval : float = 1.0
@export var chance_to_apply : float = 1.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Normal
@export var effectType : Utils.OvertimeEffectType = Utils.OvertimeEffectType.Tick
var modifiers : Array[Modifier] :
	get:
		for child in get_children():
			if child is Modifier:
				if modifiers.has(child):
					continue
				modifiers.append(child)
		return modifiers

var is_critical : bool = false
var source : Node = null
