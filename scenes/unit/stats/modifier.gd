##Used to serilialize modifiers
class_name Modifier
extends Node


@export var modifier_type : Utils.ModifierType = Utils.ModifierType.StatModifier
@export var skill_name : String = "Skill"
@export_flags("Melee", "Projectile", "Area", "Beaming") var skill_type : int = 0
@export var calculate_type : Utils.ModifyType = Utils.ModifyType.Multiply
@export var stat_type : Utils.StatType = Utils.StatType.Speed
@export var value : float = 0.1


func get_modifier_data() -> ModifierData:
	return ModifierData.new(self)
