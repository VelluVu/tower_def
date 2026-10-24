class_name ElementReaction
extends Resource

## One reaction between two elements (data only, ElementReactions runs it). A direct hit of one
## element on an enemy that carries stacks of the other sets it off. It works once both trees of
## the pair have unlock_points spent, and grows with the shared points (the lower of the two).

enum Kind
{
	#instant Fire damage around the enemy
	Combustion,
	#deeper slow, past the usual floor, and faster effect ticks for a while
	ThermalShock,
	#the enemy cannot attack buildings for a while
	Frostplague,
}

@export var kind : Kind = Kind.Combustion
@export var display_name : String = ""
@export var color : Color = Color.WHITE
@export var first_element : Utils.DamageType = Utils.DamageType.Fire
@export var second_element : Utils.DamageType = Utils.DamageType.Poison
@export var first_tree : StringName = &""
@export var second_tree : StringName = &""
## Seconds of game time before it can happen again on the same enemy.
@export var cooldown : float = 5.0
@export var unlock_points : int = 5
@export var max_points : int = 30
## Combustion: share of the triggering hit dealt around the enemy. The others: seconds it lasts.
@export var base_value : float = 1.0
## Added per shared point past unlock_points, up to max_points.
@export var value_per_point : float = 0.04
## Combustion: radius in tiles.
@export var radius : float = 1.0
## ThermalShock: extra slow (Multiply), the speed floor while it lasts, and the effect tick speed bonus.
@export var slow : float = -0.3
@export var slow_floor : float = 0.25
@export var tick_rate_bonus : float = 0.5


## The other element of the pair, or None when damage_type is not in it.
func get_partner(damage_type : Utils.DamageType) -> Utils.DamageType:
	if damage_type == first_element:
		return second_element

	if damage_type == second_element:
		return first_element

	return Utils.DamageType.None


func is_unlocked(shared_points : int) -> bool:
	return shared_points >= unlock_points


func get_value(shared_points : int) -> float:
	return ElementReaction.scaled_value(base_value, value_per_point, shared_points, unlock_points, max_points)


static func scaled_value(base : float, per_point : float, shared_points : int, unlock : int, maximum : int) -> float:
	return base + per_point * (clampi(shared_points, unlock, maximum) - unlock)


## The lower of the points spent in the two trees.
static func shared_points_of(first_spent : int, second_spent : int) -> int:
	return mini(first_spent, second_spent)
