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
	AttackRange
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
	Slowing = 1 << 2,
	Freezing = 1 << 3,
	Damaging = 1 << 4,
	Burning = 1 << 5,
	Poisoning = 1 << 6,
}
