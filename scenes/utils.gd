extends Node

const BAD_CELL : Vector2i = Vector2i(-9999,-9999)
const TILE_SIZE : int = 16

var game_control : Main

enum StatType
{
	Health,
	MaxHealth,
	Damage,
	Price,
	Speed,
	AttackRange,
	AttackSpeed,
	CriticalChance,
	CriticalMultiplier,
	ActiveDuration,
	#bonus fraction like AttackSpeed: +0.15 = burn, poison, bleed and slow 15% stronger
	EffectPotency,
	#the element stats, all Flat with base 0: points of apply chance, extra ticks, extra max stacks,
	#and a tick speed bonus fraction like AttackSpeed
	EffectChance,
	EffectDuration,
	EffectStacks,
	EffectTickRate,
	#the mechanic cards, Flat with base 0, whole numbers: enemies a bolt bounces on to after its target,
	#extra launches a moment after each attack (Nova pulses), enemies a beam chains on to
	Ricochet,
	ExtraShots,
	ChainTargets,
	#Flat with base 0: the share of an enemy's resistances a tower's hits ignore (0.1 = 10 points off each)
	ResistancePenetration,
	#Flat with base 0: at 1 or more a tower's critical hits ignore every resistance
	CriticalPenetration,
	#Flat with base 0, tiles: a direct hit also hits the enemies this close to its target (SPLASH_SHARE of it)
	SplashRadius,
	#Flat with base 0: the chance a direct hit freezes its target, and for how many seconds (bosses never freeze)
	FreezeChance,
	FreezeDuration,
	#Flat with base 0, whole numbers: enemies a bolt flies on through after its target
	Pierce,
	#Flat with base 0, whole numbers: path cells a direct hit pushes its target back (bosses and flyers never)
	Knockback,
	#Flat with base 0: seconds a direct hit's ground patch lasts, and the share of the hit it deals a second
	PatchDuration,
	PatchShare,
	#Flat with base 0: at 1 a beam also hits every enemy along its line (LINE_DAMAGE_SHARE of it)
	LineHits,
	#Flat with base 0: shards a direct hit splits into (whole number) and the share of the hit each deals
	SplitCount,
	SplitShare,
	#Flat with base 0, whole number: when a poisoned enemy dies to this tower, its nearest neighbours get half its hit, poison included
	PoisonSpread,
}

enum TileType
{
	None = 0,
	Normal = 1 << 0, #1
	Blocking = 1 << 1, #2
	OnlyBuildable = 1 << 2, #4
	OnlyWalkable = 1 << 3, #8
}

enum TileEffect
{
	None = 0,
	NoEffect = 1 << 0,
	Slowing = 1 << 1,
	Freezing = 1 << 2,
	Damaging = 1 << 3,
	Burning = 1 << 4,
	Poisoning = 1 << 5,
}

enum DamageType
{
	None = 0,
	Physical = 1 << 0,
	Fire = 1 << 1,
	Frost = 1 << 2,
	Poison = 1 << 3,
}

enum OvertimeEffectType
{
	Tick,
	Stack,
}

enum ModifyType
{
	Flat,
	Multiply,
	#percent bonuses of this type are summed before they multiply ("increased"), Multiply ones compound ("more")
	Additive,
}

enum ModifierType
{
	StatModifier,
	SkillModifier,
	GlobalModifier,
}

enum Element
{
	None = 0,
	Physical = 1 << 0,
	Fire = 1 << 1,
	Frost = 1 << 2,
	Poison = 1 << 3,
}

enum SkillType
{
	None = 0,
	Melee = 1 << 0,
	Projectile = 1 << 1,
	Area = 1 << 2,
	Beaming = 1 << 3,
}

## Each mode of a level earns its own talent points.
enum LevelMode
{
	Normal,
	Hard,
	Survival,
}

## Which enemy in range a tower that picks targets (Bolter, Beamer) shoots; set per tower (TargetPicker).
enum TargetTactic
{
	## Closest to the castle along its path.
	First,
	## The most health left.
	Strongest,
	## Nearest to the tower.
	Closest,
	## Farthest from the tower, still in range.
	Farthest,
	## The highest speed.
	Fastest,
	## The least health left: finishes off the wounded.
	Weakest,
	## Farthest from the castle along its path.
	Last,
}

func get_damage_type_color(damage_type : DamageType) -> Color:
	match(damage_type):
		DamageType.Physical:
			return Color.WHITE
		DamageType.Fire:
			return Color.FIREBRICK
		DamageType.Frost:
			return Color.CYAN
		DamageType.Poison:
			return Color.CHARTREUSE
		_:
			return Color.WHITE


## The first direct child of parent that is a type (a class_name script or a native class), or null.
## For the getters that find a unit's parts (Skill, BeehaveTree, ...) when their export is empty.
static func find_child_of_type(parent : Node, type : Variant) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, type):
			return child
	return null
