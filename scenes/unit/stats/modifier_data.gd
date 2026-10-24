class_name ModifierData
extends RefCounted


var modifier_type : Utils.ModifierType = Utils.ModifierType.StatModifier
var skill_name : String = "Skill"
var skill_type : int = 0
var calculate_type : Utils.ModifyType = Utils.ModifyType.Multiply
var stat_type : Utils.StatType = Utils.StatType.Speed
var value : float = 0.1
#need skill type flags?

func _init(modifier : Modifier = null) -> void:
	if modifier == null:
		return

	calculate_type = modifier.calculate_type
	stat_type = modifier.stat_type
	value = modifier.value
	modifier_type = modifier.modifier_type
	skill_name = modifier.skill_name
	skill_type = modifier.skill_type


## A copy with the value multiplied by factor.
func scaled(factor : float) -> ModifierData:
	var copy : ModifierData = ModifierData.new()
	copy.modifier_type = modifier_type
	copy.skill_name = skill_name
	copy.skill_type = skill_type
	copy.calculate_type = calculate_type
	copy.stat_type = stat_type
	copy.value = value * factor
	return copy
