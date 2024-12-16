class_name EvolveResource
extends Resource


@export var evolve_icon : CompressedTexture2D = null
@export var evolve_level_reguirement : int = 0

@export var modifier_type : Utils.ModifierType
@export_flags("Melee", "Projectile", "Area", "Beaming") var skill_type : int = 0
@export var skill_name : String = "Skill"

@export_flags("Normal", "Fire", "Frost", "Poison") var elements : int = 0

@export var modify_stat_type : Utils.StatType = Utils.StatType.Damage
@export var modify_type : Utils.ModifyType = Utils.ModifyType.Multiply

@export var is_randomized_modify_value : bool = true
@export var is_percent : bool = true
#if using resource elsewhere this need to be calculated only once and resource should be local to scene?
#mark modify value calculated after getting data and return 
@export var modify_value : float = 0.1 : 
	get:
		if is_value_calculated:
			return modify_value
		
		if modify_stat_type == Utils.StatType.AttackRange:
			is_value_calculated = true
			return modify_value
		
		var random : float = randf()
		
		#epic success
		if random < 0.2:
			modify_value *= 3 if modify_type == Utils.ModifyType.Multiply else 3
			is_value_calculated = true
			return modify_value
		
		#rare success
		if random < 0.5:
			modify_value *= 2 if modify_type == Utils.ModifyType.Multiply else 2
			
		is_value_calculated = true
		return modify_value

@export var evolve_name : String = "All Damage"
var is_value_calculated : bool = false

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
