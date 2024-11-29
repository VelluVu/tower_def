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
	ActiveDuration
}

enum TileType
{
	Normal = 1 << 0, #1
	Blocking = 1 << 1, #2
	OnlyBuildable = 1 << 2, #4
	OnlyWalkable = 1 << 3, #8
}

enum TileEffect
{
	NoEffect = 1 << 0,
	Slowing = 1 << 1,
	Freezing = 1 << 2,
	Damaging = 1 << 3,
	Burning = 1 << 4,
	Poisoning = 1 << 5,
}

enum DamageType
{
	Normal = 1 << 0,
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
}

enum Element
{
	Normal = 1 << 0,
	Fire = 1 << 1,
	Frost = 1 << 2,
	Poison = 1 << 3,
}

enum SkillType
{
	Melee = 1 << 0,
	Projectile = 1 << 1,
	Area = 1 << 2,
	Beaming = 1 << 3,
}

func get_damage_type_color(damage_type : DamageType) -> Color:
	match(damage_type):
		DamageType.Normal:
			return Color.WHITE
		DamageType.Fire:
			return Color.FIREBRICK
		DamageType.Frost:
			return Color.CYAN
		DamageType.Poison:
			return Color.CHARTREUSE
		_:
			return Color.WHITE
