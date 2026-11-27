class_name UpgradeTooltipText
extends RefCounted

## What each gold upgrade button gives, for its tooltip (GoldUpgradeOption.description).

const THIS_TOWER_TEXT : String = "For this building only."
const EVERY_WALL_TEXT : String = "For every wall, placed now or later."
const THIS_WALL_TEXT : String = "For this wall only; it stays until sold."
const EVERY_ELEMENT_WALL_FORMAT : String = "For every %s, placed now or later."
const LOCKED_NOTE : String = "Learn the talent node to unlock it."
const STAT_LINE_FORMAT : String = "%s %s"
const RANK_INTRO_TEXT : String = "A rank: buy it again and again, each one dearer, until every stat is at its cap."
const RANK_LINE_FORMAT : String = "%s %s (now %s, at most %s)"
## Flat modifiers on these stats are chances, shown as percent.
const CHANCE_STATS : Array[Utils.StatType] = [Utils.StatType.CriticalChance, Utils.StatType.EffectChance]

const ELEMENT_EFFECTS : Dictionary[Utils.Element, String] = {
	Utils.Element.Physical: "Hard hits that crit more often.",
	Utils.Element.Fire: "Sets enemies burning: damage over time.",
	Utils.Element.Frost: "Slows the enemies it hits.",
	Utils.Element.Poison: "Poison stacks eat away at enemies' health.",
}
const WALL_ELEMENT_EFFECTS : Dictionary[Utils.Element, String] = {
	Utils.Element.Physical: "Enemies pause longer at every turn beside it, and walk a little slower.",
	Utils.Element.Fire: "Burns enemies walking beside it.",
	Utils.Element.Frost: "Enemies beside it walk slower: the strongest maze slow.",
	Utils.Element.Poison: "Poisons enemies walking beside it.",
}
## [T2, T3] per wall element.
const WALL_TIER_EFFECTS : Dictionary[Utils.Element, Array] = {
	Utils.Element.Physical: ["Takes 20% less damage and stuns 10% of its attackers for 1 s.", "Enemies take longer detours around it."],
	Utils.Element.Fire: ["Burns its attackers twice as hard.", "Explodes when destroyed: 8 Fire damage within 1.5 tiles."],
	Utils.Element.Frost: ["Colder ground: enemies beside it walk slower still.", "Freezes its attackers for 1 s."],
	Utils.Element.Poison: ["Poisons twice as hard, and its attackers hit 25% softer.", "The poison spreads to enemies within a tile of its attacker."],
}


## "Damage +30%" per stat step of a plain upgrade (plus the evolved steps after the element).
static func for_upgrade(data : BuildingUpgradeData, is_evolved : bool) -> String:
	var lines : PackedStringArray = []
	for resource in data.upgrade_resources:
		lines.append(resource_line(resource))
	if is_evolved:
		for resource in data.evolved_upgrade_resources:
			lines.append(resource_line(resource))
	lines.append(EVERY_WALL_TEXT if data.is_per_type else THIS_TOWER_TEXT)
	return "\n".join(lines)


## The element's effect, then its stat changes.
static func for_element(leaf : ElementEvolveLeaf) -> String:
	var lines : PackedStringArray = [ELEMENT_EFFECTS.get(leaf.evolve_element, "")]
	for modifier in leaf.modifiers:
		lines.append(STAT_LINE_FORMAT % [stat_name(modifier.stat_type), _format(modifier.value, modifier.calculate_type, modifier.stat_type)])
	return "\n".join(lines)


static func for_tier(data : EvolveTierData, is_locked : bool) -> String:
	return "%s\n%s" % [data.info, LOCKED_NOTE] if is_locked else data.info


static func for_wall_element(element : Utils.Element) -> String:
	return "%s\n%s" % [WALL_ELEMENT_EFFECTS.get(element, ""), THIS_WALL_TEXT]


static func for_wall_tier(element : Utils.Element, wall_name : String, tier : int, is_locked : bool) -> String:
	var effects : Array = WALL_TIER_EFFECTS.get(element, [])
	var lines : PackedStringArray = [effects[tier - 2] if tier - 2 < effects.size() else "", EVERY_ELEMENT_WALL_FORMAT % wall_name.to_lower()]
	if is_locked:
		lines.append(LOCKED_NOTE)
	return "\n".join(lines)


## "Damage +5% (now +15%, at most +50%)" per rank step, then who it reaches.
static func for_rank(data : RankData, ranks_bought : int, is_per_type : bool) -> String:
	var lines : PackedStringArray = [RANK_INTRO_TEXT]
	for index in data.steps.size():
		var step : EvolveResource = data.steps[index]
		var cap : float = data.caps[index] if index < data.caps.size() else INF
		var now : float = data.get_total(index, ranks_bought)
		var gain : float = data.get_total(index, ranks_bought + 1) - now
		lines.append(RANK_LINE_FORMAT % [step.evolve_name, UpgradeCard._format_value(gain, step.modify_type, step.is_percent),
			UpgradeCard._format_value(now, step.modify_type, step.is_percent), UpgradeCard._format_value(cap, step.modify_type, step.is_percent)])
	lines.append(EVERY_WALL_TEXT if is_per_type else THIS_TOWER_TEXT)
	return "\n".join(lines)


static func resource_line(resource : EvolveResource) -> String:
	return STAT_LINE_FORMAT % [resource.evolve_name, UpgradeCard._format_value(resource.modify_value, resource.modify_type, resource.is_percent)]


static func stat_name(stat_type : Utils.StatType) -> String:
	return UpgradeCard._stat_name(stat_type)


#a Flat chance (0.1) reads as "+10%", other Flat values as they are
static func _format(value : float, modify_type : Utils.ModifyType, stat_type : Utils.StatType) -> String:
	var is_percent : bool = modify_type != Utils.ModifyType.Flat or CHANCE_STATS.has(stat_type)
	var shown_type : Utils.ModifyType = Utils.ModifyType.Additive if modify_type == Utils.ModifyType.Flat else modify_type
	return UpgradeCard._format_value(value, shown_type, is_percent)
