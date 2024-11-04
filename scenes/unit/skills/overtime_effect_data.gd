class_name OvertimeEffectData
extends Node


@export var max_ticks : int = 3
@export var tick_damage : float = 1.0
@export var tick_interval : float = 1.0
@export var chance_to_apply : float = 1.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Normal
@export var effectType : Utils.OvertimeEffectType = Utils.OvertimeEffectType.Tick
var source : Node = null
