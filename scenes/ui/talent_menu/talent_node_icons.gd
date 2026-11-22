class_name TalentNodeIcons
extends RefCounted

## The 7x7 icon a talent node shows (its first effect's), so the tree says what each node does
## before it is clicked (polish, 2026-11-22). Icons in assets/art/ui/stat_icons/, drawn from text grids.

const DAMAGE : Texture2D = preload("res://assets/art/ui/stat_icons/stat_damage.png")
const SPEED : Texture2D = preload("res://assets/art/ui/stat_icons/stat_speed.png")
const RANGE : Texture2D = preload("res://assets/art/ui/stat_icons/stat_range.png")
const CRIT : Texture2D = preload("res://assets/art/ui/stat_icons/stat_crit.png")
const HEALTH : Texture2D = preload("res://assets/art/ui/stat_icons/stat_health.png")
const GOLD : Texture2D = preload("res://assets/art/ui/stat_icons/stat_price.png")
const EFFECT : Texture2D = preload("res://assets/art/ui/stat_icons/stat_effect.png")
const TIER : Texture2D = preload("res://assets/art/ui/stat_icons/stat_tier.png")
const WALL : Texture2D = preload("res://assets/art/ui/stat_icons/stat_wall.png")
const WEAKEN : Texture2D = preload("res://assets/art/ui/stat_icons/stat_weaken.png")
const FREEZE : Texture2D = preload("res://assets/art/ui/stat_icons/stat_freeze.png")
const CARD : Texture2D = preload("res://assets/art/ui/stat_icons/stat_card.png")
const DRAGON : Texture2D = preload("res://assets/art/ui/stat_icons/stat_dragon.png")

const STAT_ICONS : Dictionary[Utils.StatType, Texture2D] = {
	Utils.StatType.Damage: DAMAGE,
	Utils.StatType.AttackSpeed: SPEED,
	Utils.StatType.AttackRange: RANGE,
	Utils.StatType.CriticalChance: CRIT,
	Utils.StatType.CriticalMultiplier: CRIT,
	Utils.StatType.Health: HEALTH,
	Utils.StatType.MaxHealth: HEALTH,
	Utils.StatType.Price: GOLD,
	Utils.StatType.EffectPotency: EFFECT,
	Utils.StatType.EffectChance: EFFECT,
	Utils.StatType.EffectDuration: EFFECT,
	Utils.StatType.EffectStacks: EFFECT,
	Utils.StatType.EffectTickRate: EFFECT,
	Utils.StatType.PatchDuration: EFFECT,
	Utils.StatType.PatchShare: EFFECT,
	Utils.StatType.FreezeChance: FREEZE,
	Utils.StatType.FreezeDuration: FREEZE,
}

const KIND_ICONS : Dictionary[TalentEffect.Kind, Texture2D] = {
	TalentEffect.Kind.StartGold: GOLD,
	TalentEffect.Kind.WaveGold: GOLD,
	TalentEffect.Kind.UpgradeDiscount: GOLD,
	TalentEffect.Kind.SellRefund: GOLD,
	TalentEffect.Kind.FirstUpgradeDiscount: GOLD,
	TalentEffect.Kind.EarlyStartBonus: GOLD,
	TalentEffect.Kind.UnlockTier: TIER,
	TalentEffect.Kind.Vulnerability: WEAKEN,
	TalentEffect.Kind.Weakness: WEAKEN,
	TalentEffect.Kind.MazeSlow: WALL,
	TalentEffect.Kind.TurnPause: WALL,
	TalentEffect.Kind.WallThorns: WALL,
	TalentEffect.Kind.WallArmor: WALL,
	TalentEffect.Kind.Mending: HEALTH,
	TalentEffect.Kind.CardOffer: CARD,
	TalentEffect.Kind.FreezeLonger: FREEZE,
	TalentEffect.Kind.FreezeExtra: FREEZE,
	TalentEffect.Kind.Strike: CRIT,
	TalentEffect.Kind.DeathBurst: CRIT,
	TalentEffect.Kind.CastleDragon: DRAGON,
}


## Null for a node without effects (not built yet): it shows no icon.
static func for_node(node : TalentNode) -> Texture2D:
	for effect in node.effects:
		if effect != null:
			return for_effect(effect)
	return null


## A building stat by its stat (the mechanic stats, such as pierce and splash, as a burst); the rest by kind.
static func for_effect(effect : TalentEffect) -> Texture2D:
	if effect.kind == TalentEffect.Kind.BuildingStat:
		return STAT_ICONS.get(effect.stat_type, CRIT)
	return KIND_ICONS.get(effect.kind, null)
