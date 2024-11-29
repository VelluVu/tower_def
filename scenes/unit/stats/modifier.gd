##Used to serilialize modifiers
class_name Modifier
extends Node

@export var is_skill_modifier : bool = false
@export var skill_name : String = "Skill"
@export var skill_type : Utils.SkillType = Utils.SkillType.Projectile
@export var type : Utils.ModifyType = Utils.ModifyType.Multiply
@export var stat : Utils.StatType = Utils.StatType.Speed
@export var value : float = 0.1


func get_modifier_data() -> ModifierData:
	return ModifierData.new(self)
