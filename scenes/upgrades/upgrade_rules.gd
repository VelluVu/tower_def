class_name UpgradeRules
extends RefCounted

## Pure rules for the level upgrades: XP curve, value rolls, which cards fit a tower, and the gold upgrade steps.

enum GoldStep { Upgrade, Evolve, Max }

const EPIC_ROLL_CHANCE : float = 0.2
const RARE_ROLL_CHANCE : float = 0.5
const EPIC_MULTIPLIER : float = 3.0
const RARE_MULTIPLIER : float = 2.0
#16 since enemy health went to 1/8 (2026-11-26), so a kill gives the same XP and the cards come as before
const XP_PER_MAX_HEALTH : float = 16.0
#about 7 Weakling kills (max health 1.875, 16 XP per max health)
const FIRST_LEVEL_XP : float = 150.0
#each level-up needs this much more XP than the one before, times the level: 150, 170, 210, 270, ...
const XP_STEP : float = 20.0
#the share of a card's value that still counts past the stat's soft cap
const SOFT_CAP_EFFICIENCY : float = 0.5
#a rare card's chance to be drawn into an offer, against 1.0 for a common one (0.35 until 2026-11-27, the user: rares came
#too often; 0.1 keeps the rate halved with the five rares added that day: 10-24% of offers had one, now 8-12%)
const RARE_OFFER_WEIGHT : float = 0.1
#a plain damage card's chance against 1.0 for the other common cards (no drawback, Damage stat): the offers lean to
#range, speed, crits and effects, so damage grows slower inside a level while the card count stays (the user, 2026-11-26)
const DAMAGE_OFFER_WEIGHT : float = 0.6
#a building sold after the wave or build break it was placed in gets this share of its price back
const LATE_SELL_SHARE : float = 0.75


## XP for one kill before the XP cards: 16 per max health, times the enemy's own multiplier
## (swarm enemies come in big groups, so each one gives less).
static func kill_xp(max_health : float, xp_multiplier : float) -> float:
	return max_health * XP_PER_MAX_HEALTH * xp_multiplier


## XP needed to go from this level to the next: 200, 250, 350, 500, 700, ...
static func xp_required(level : int) -> float:
	return FIRST_LEVEL_XP + XP_STEP * level * (level - 1) / 2.0


## roll is a random number in [0, 1); passed in so the rule can be tested.
static func roll_value(resource : EvolveResource, roll : float) -> float:
	if not resource.is_randomized_modify_value:
		return resource.modify_value

	if roll < EPIC_ROLL_CHANCE:
		return resource.modify_value * EPIC_MULTIPLIER

	if roll < RARE_ROLL_CHANCE:
		return resource.modify_value * RARE_MULTIPLIER

	return resource.modify_value


## The card total that counts: all of it up to soft_cap, SOFT_CAP_EFFICIENCY of the rest, never above hard_cap.
static func capped_bonus(card_total : float, soft_cap : float, hard_cap : float) -> float:
	if card_total <= soft_cap:
		return minf(card_total, hard_cap)

	return minf(soft_cap + (card_total - soft_cap) * SOFT_CAP_EFFICIENCY, hard_cap)


static func fits_tower(resource : EvolveResource, skill : Skill, element : Utils.Element, level : int) -> bool:
	if level < resource.evolve_level_reguirement:
		return false

	if not has_any_flag(resource.elements, element):
		return false

	if skill == null:
		return resource.modifier_type != Utils.ModifierType.SkillModifier and resource.skill_type == 0

	#a Buffer never attacks: its own stats do nothing, so no card fits it
	if skill.skill_type == Utils.SkillType.Support:
		return false

	#a trap's range is its trigger area, not a reach to grow or shrink
	if skill.skill_type == Utils.SkillType.Melee and (resource.modify_stat_type == Utils.StatType.AttackRange
			or (resource.has_drawback and resource.drawback_stat_type == Utils.StatType.AttackRange)):
		return false

	if skill.base_active_time <= 0.0 and resource.modify_stat_type == Utils.StatType.ActiveDuration:
		return false

	#skill_type flags limit any card to those skills, unit stat cards too (the mechanic cards)
	if resource.modifier_type == Utils.ModifierType.SkillModifier or resource.skill_type != 0:
		return has_any_flag(resource.skill_type, skill.skill_type)

	return true


## A weighted draw without replacement (Efraimidis-Spirakis): sort the pool by this key, highest first.
## roll is a random number in (0, 1); passed in so the rule can be tested.
static func offer_key(resource : EvolveResource, roll : float) -> float:
	return pow(roll, 1.0 / offer_weight(resource))


## How often a card comes up in an offer, against 1.0 for a plain common card.
static func offer_weight(resource : EvolveResource) -> float:
	if resource.rarity == EvolveResource.Rarity.Rare:
		return RARE_OFFER_WEIGHT
	if resource.modify_stat_type == Utils.StatType.Damage and not resource.has_drawback and resource.card_target == EvolveResource.CardTarget.Buildings:
		return DAMAGE_OFFER_WEIGHT
	return 1.0


## upgrades_before_next_tier upgrades come before the next evolve tier (BuildingUpgradeData.upgrades_before_tier).
## A tier without data stays out and the upgrades go on past it.
static func next_gold_step(upgrades_bought : int, tiers_evolved : int, upgrade_count : int, tier_count : int, upgrades_before_next_tier : int) -> GoldStep:
	if tiers_evolved < tier_count and upgrades_bought >= upgrades_before_next_tier:
		return GoldStep.Evolve

	if upgrades_bought < upgrade_count:
		return GoldStep.Upgrade

	return GoldStep.Max


## The extra gold a building with a price step costs when buildings_on_map stepped buildings are placed.
static func price_step_extra(step : float, buildings_on_map : int) -> float:
	return step * buildings_on_map


## Whole gold, rounded up so a cheap building never gets a free step.
static func gold_price(building_price : float, ratio : float) -> float:
	return ceilf(building_price * ratio)


## Gold back for selling a building that cost this price: all of it in the round it was
## placed in (a misplacement can be undone), LATE_SELL_SHARE of it later, rounded up.
static func sell_refund(price : float, is_same_round : bool) -> float:
	if is_same_round:
		return price
	return ceilf(price * LATE_SELL_SHARE)


static func has_any_flag(a : int, b : int) -> bool:
	return (a & b) != 0
