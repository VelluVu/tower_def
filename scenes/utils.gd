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

## Each mode of a level earns its own talent points (docs/design/progression.md, Level Modes).
enum LevelMode
{
	Normal,
	Hard,
	Survival,
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
