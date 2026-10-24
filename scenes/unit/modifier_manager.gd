class_name ModifierManager
extends Node


## Slows (negative Multiply on Speed) never take a unit below this share of its unslowed speed.
const SLOW_FLOOR : float = 0.4

@onready var actor : Node = get_parent()

#Thermal Shock lowers it for a while
var slow_floor : float = SLOW_FLOOR


func add_modifier(modifier : ModifierData) -> void:
	match(modifier.modifier_type):
		Utils.ModifierType.StatModifier:
			actor.stats.get_stat(modifier.stat_type).add_modifier(modifier)
		Utils.ModifierType.SkillModifier:
			# what if have multiple skills, need a skill manager and check stat type of modifier
			actor.skill.stats.get_stat(modifier.stat_type).add_modifier(modifier)
		Utils.ModifierType.GlobalModifier:
			actor.stats.get_stat(modifier.stat_type).add_modifier(modifier)
	
	calculate_modifier(modifier.stat_type)


func remove_modifier(modifier : ModifierData) -> void:
	match(modifier.modifier_type):
		Utils.ModifierType.StatModifier:
			actor.stats.get_stat(modifier.stat_type).remove_modifier(modifier)
		Utils.ModifierType.SkillModifier:
			# what if have multiple skills, need a skill manager and check stat type of modifier
			actor.skill.stats.get_stat(modifier.stat_type).remove_modifier(modifier)
		Utils.ModifierType.GlobalModifier:
			actor.stats.get_stat(modifier.stat_type).remove_modifier(modifier)
	
	calculate_modifier(modifier.stat_type)


func calculate_all_modifiers() -> void:
	#a stat on both the unit and the skill is calculated once, the result goes to the skill stat
	var calculated_stat_types : Array[Utils.StatType]
	
	for stat : Stat in actor.stats.stats:
		if not stat.has_modifiers:
			continue
		
		calculate_modifier(stat.type)
		calculated_stat_types.append(stat.type)
	
	for stat : Stat in actor.skill.stats.stats:
		if calculated_stat_types.has(stat.type):
			continue
		
		calculate_modifier(stat.type)


## The unit stat and the skill stat of a type count as one value; the result is written to the skill
## stat when the skill has one, otherwise to the unit stat.
func calculate_modifier(stat_type : Utils.StatType) -> void:
	var main_stat : Stat = actor.stats.get_stat(stat_type)
	# need to be changed if have multiple skills: then only the matching skill's stat should change
	#this can be null, skills don't have all kind of stats
	var skill_stat : Stat = actor.skill.stats.get_stat(stat_type)
	var base : float = 0.0
	var flat : Array[ModifierData] = []
	var additive : Array[ModifierData] = []
	var multiply : Array[ModifierData] = []
	
	for stat in [main_stat, skill_stat]:
		if stat == null:
			continue
		
		base += stat.base_value
		flat.append_array(stat.flat_modifiers)
		flat.append_array(stat.global_flat_modifiers)
		additive.append_array(stat.additive_modifiers)
		additive.append_array(stat.global_additive_modifiers)
		multiply.append_array(stat.multiply_modifiers)
		multiply.append_array(stat.global_multiply_modifiers)
	
	var modified_value : float = combine(base, flat, additive, multiply)

	if stat_type == Utils.StatType.Speed:
		modified_value = floor_slows(modified_value, base, flat, additive, multiply, slow_floor)

	if skill_stat != null:
		skill_stat.value = modified_value
	elif main_stat != null:
		main_stat.value = modified_value


## (base + flats) * (1 + sum of additive) * product of (1 + multiply). Static so it can be tested.
static func combine(base : float, flat : Array[ModifierData], additive : Array[ModifierData], multiply : Array[ModifierData]) -> float:
	var value : float = base
	
	for modifier in flat:
		value += modifier.value
	
	var additive_sum : float = 0.0
	
	for modifier in additive:
		additive_sum += modifier.value
	
	value *= 1.0 + additive_sum
	
	for modifier in multiply:
		value *= 1.0 + modifier.value

	return value


## The slowed value, but at least floor_share of the value without the slows. Static so it can be tested.
static func floor_slows(slowed_value : float, base : float, flat : Array[ModifierData], additive : Array[ModifierData], multiply : Array[ModifierData], floor_share : float = SLOW_FLOOR) -> float:
	var boosts : Array[ModifierData] = []

	for modifier in multiply:
		if modifier.value >= 0.0:
			boosts.append(modifier)

	return maxf(slowed_value, combine(base, flat, additive, boosts) * floor_share)
