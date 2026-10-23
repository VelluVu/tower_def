class_name EvolveResource
extends Resource


@export var evolve_icon : CompressedTexture2D = null
@export var evolve_level_reguirement : int = 0

@export var modifier_type : Utils.ModifierType
@export_flags("Melee", "Projectile", "Area", "Beaming") var skill_type : int = 0
@export var skill_name : String = "Skill"

@export_flags("Physical", "Fire", "Frost", "Poison") var elements : int = 0

@export var modify_stat_type : Utils.StatType = Utils.StatType.Damage
@export var modify_type : Utils.ModifyType = Utils.ModifyType.Multiply

@export var is_randomized_modify_value : bool = true
@export var is_percent : bool = true
#base value; each UpgradeCard rolls its own bonus from it (UpgradeRules.roll_value)
@export var modify_value : float = 0.1
@export var evolve_name : String = "All Damage"

func get_modifier_data() -> ModifierData:
	var modifier_data : ModifierData = ModifierData.new()
	modifier_data.modifier_type = modifier_type
	modifier_data.stat_type = modify_stat_type
	modifier_data.calculate_type = modify_type
	modifier_data.value = modify_value
	modifier_data.skill_name = skill_name
	modifier_data.skill_type = skill_type
	return modifier_data


func evolve(_actor : Node) -> void:
	_actor.modifier_manager.add_modifier(get_modifier_data())
