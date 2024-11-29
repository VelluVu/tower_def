class_name EvolveResource
extends Resource


@export var evolve_icon : CompressedTexture2D = null
@export var evolve_level_reguirement : int = 0

@export var is_skill_modifier : bool = false
@export_flags("Melee", "Projectile", "Area", "Beaming") var skill_type : int = 0
@export var skill_name : String = "Skill"

@export_flags("Normal", "Fire", "Frost", "Poison") var elements : int = 0

@export var modify_stat_type : Utils.StatType = Utils.StatType.Damage
@export var modify_type : Utils.ModifyType = Utils.ModifyType.Multiply

@export var modify_Value : float = 0.1 : 
	get:
		var random : float = randf()
		if random < 0.2:
			return modify_Value * 3 if modify_type == Utils.ModifyType.Multiply else modify_Value * 2
		if random < 0.5:
			return modify_Value * 2 if modify_type == Utils.ModifyType.Multiply else modify_Value * 1.5
		return modify_Value

@export var evolve_name : String = "All Damage"


func get_modifier_data() -> ModifierData:
	var modifier_data : ModifierData = ModifierData.new()
	modifier_data.stat = modify_stat_type
	modifier_data.type = modify_type
	modifier_data.value = modify_Value
	return modifier_data


func evolve(_actor : Node) -> void:
	var stat : Stat = null
	
	if is_skill_modifier:
		stat = _actor.skill.stats.get_stat(modify_stat_type)
		stat.add_modifier_data(get_modifier_data())
		return
	
	stat = _actor.stats.get_stat(modify_stat_type)
	stat.add_modifier_data(get_modifier_data())
