class_name UpgradeRules
extends RefCounted

## Pure rules for the level upgrades: XP curve, value rolls, which cards fit a tower, and the gold upgrade steps.

enum GoldStep { Upgrade, Evolve, Max }

const EPIC_ROLL_CHANCE : float = 0.2
const RARE_ROLL_CHANCE : float = 0.5
const EPIC_MULTIPLIER : float = 3.0
const RARE_MULTIPLIER : float = 2.0
#10 Weakling kills (max health 15, 2 XP per max health)
const FIRST_LEVEL_XP : float = 300.0


## XP needed to go from this level to the next: 300, 400, 600, 900, ...
static func xp_required(level : int) -> float:
	return FIRST_LEVEL_XP + 100.0 * level * (level - 1) / 2.0


## roll is a random number in [0, 1); passed in so the rule can be tested.
static func roll_value(resource : EvolveResource, roll : float) -> float:
	if not resource.is_randomized_modify_value or resource.modify_stat_type == Utils.StatType.AttackRange:
		return resource.modify_value

	if roll < EPIC_ROLL_CHANCE:
		return resource.modify_value * EPIC_MULTIPLIER

	if roll < RARE_ROLL_CHANCE:
		return resource.modify_value * RARE_MULTIPLIER

	return resource.modify_value


static func fits_tower(resource : EvolveResource, skill : Skill, element : Utils.Element, level : int) -> bool:
	if level < resource.evolve_level_reguirement:
		return false

	if not has_any_flag(resource.elements, element):
		return false

	if skill == null:
		return resource.modifier_type != Utils.ModifierType.SkillModifier

	if skill.skill_type == Utils.SkillType.Melee and resource.modify_stat_type == Utils.StatType.AttackRange:
		return false

	if skill.base_active_time <= 0.0 and resource.modify_stat_type == Utils.StatType.ActiveDuration:
		return false

	if resource.modifier_type == Utils.ModifierType.SkillModifier:
		return has_any_flag(resource.skill_type, skill.skill_type)

	return true


## upgrades_per_tier upgrades come before each evolve tier. A tier without data stays locked
## and the upgrades go on past it.
static func next_gold_step(upgrades_bought : int, tiers_evolved : int, upgrade_count : int, tier_count : int, upgrades_per_tier : int) -> GoldStep:
	if tiers_evolved < tier_count and upgrades_bought >= (tiers_evolved + 1) * upgrades_per_tier:
		return GoldStep.Evolve

	if upgrades_bought < upgrade_count:
		return GoldStep.Upgrade

	return GoldStep.Max


## Whole gold, rounded up so a cheap building never gets a free step.
static func gold_price(building_price : float, ratio : float) -> float:
	return ceilf(building_price * ratio)


static func has_any_flag(a : int, b : int) -> bool:
	return (a & b) != 0
