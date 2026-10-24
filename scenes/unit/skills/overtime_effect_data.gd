class_name OvertimeEffectData
extends Node


#ticks before the effect ends, 0 = never (regeneration)
@export var max_count : int = 3
#fixed damage per tick, used when hit_share is 0 (regeneration, effects not caused by a hit)
@export var tick_damage : float = 1.0
#share of the hit that applied the effect, per tick; taken when applied, so a stack keeps its strength
@export var hit_share : float = 0.0
@export var tick_interval : float = 1.0
@export var chance_to_apply : float = 1.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Physical
#Stack: an element effect, capped at max_stacks per enemy for its damage type; Tick: runs on its own
@export var effectType : Utils.OvertimeEffectType = Utils.OvertimeEffectType.Tick
@export var max_stacks : int = 3
@export var is_healing : bool = false
@export var is_shielding : bool = false

var modifier_datas : Array[ModifierData] :
	get:
		if is_serialized_modifiers_added:
			return modifier_datas
		
		for modifier in modifiers:
			var data : ModifierData = ModifierData.new(modifier)
			modifier_datas.append(data)
			added_serialized_modifiers_datas.append(data)
		
		is_serialized_modifiers_added = true
		return modifier_datas

var modifiers : Array[Modifier] :
	get:
		for child in get_children():
			if child is Modifier:
				if modifiers.has(child):
					continue
				modifiers.append(child)
		return modifiers

var is_serialized_modifiers_added : bool = false :
	set(value):
		if value == is_serialized_modifiers_added:
			return
		
		is_serialized_modifiers_added = value
		
		if is_serialized_modifiers_added == false:
			if added_serialized_modifiers_datas.is_empty():
				return
				
			if modifier_datas.is_empty():
				return
				
			for data in added_serialized_modifiers_datas:
				if modifier_datas.has(data):
					modifier_datas.erase(data)

var is_critical : bool = false
var source : Node = null
#the source's effect stats when the hit was made (read_source_stats)
var potency : float = 0.0
var chance_bonus : float = 0.0
var duration_bonus : int = 0
var stacks_bonus : int = 0
var tick_rate : float = 0.0
var added_serialized_modifiers_datas : Array[ModifierData]


## Copies the hitting unit's effect stats; each hit has its own copy of this data, so this is safe.
func read_source_stats(source_stats : Stats) -> void:
	potency = source_stats.get_stat_value(Utils.StatType.EffectPotency)
	chance_bonus = source_stats.get_stat_value(Utils.StatType.EffectChance)
	duration_bonus = roundi(source_stats.get_stat_value(Utils.StatType.EffectDuration))
	stacks_bonus = roundi(source_stats.get_stat_value(Utils.StatType.EffectStacks))
	tick_rate = source_stats.get_stat_value(Utils.StatType.EffectTickRate)


func get_chance() -> float:
	return chance_to_apply + chance_bonus


func get_tick_count() -> int:
	return max_count + duration_bonus if max_count > 0 else 0


func get_max_stacks() -> int:
	return max_stacks + stacks_bonus


#a bonus fraction like attack speed: +0.1 = ticks 10% faster
func get_tick_interval() -> float:
	return tick_interval / (1.0 + tick_rate)


func get_tick_damage(hit_damage : float) -> float:
	return OvertimeEffectData.scaled_tick_damage(tick_damage, hit_share, hit_damage, potency)


## Potency scales damage from a hit; a fixed tick (regeneration) stays as it is.
static func scaled_tick_damage(fixed_damage : float, share : float, hit_damage : float, effect_potency : float) -> float:
	if share <= 0.0:
		return fixed_damage

	return hit_damage * share * (1.0 + effect_potency)


#turn back off when new serialized modifiers are added
