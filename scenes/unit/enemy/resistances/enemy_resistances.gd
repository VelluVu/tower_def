class_name EnemyResistances
extends Resource

## An enemy's resistances, a share of the damage it ignores: per element, and per tower kind (by the
## hitting tower's skill type). Always 0-75%: no immunity and no bonus damage; a weakness is just
## the lowest resistance. One profile per faction role in this folder, shared by the enemy scenes.

const MAX_RESISTANCE : float = 0.75

@export_group("Element")
@export_range(0.0, 0.75) var physical : float = 0.0
@export_range(0.0, 0.75) var fire : float = 0.0
@export_range(0.0, 0.75) var frost : float = 0.0
@export_range(0.0, 0.75) var poison : float = 0.0
@export_group("Tower")
## Bolter-like towers (projectiles), and the traps' melee strikes.
@export_range(0.0, 0.75) var projectile : float = 0.0
## Nova-like towers (area bursts).
@export_range(0.0, 0.75) var area : float = 0.0
## Beamer-like towers.
@export_range(0.0, 0.75) var beam : float = 0.0


func get_element(damage_type : Utils.DamageType) -> float:
	match damage_type:
		Utils.DamageType.Physical:
			return physical
		Utils.DamageType.Fire:
			return fire
		Utils.DamageType.Frost:
			return frost
		Utils.DamageType.Poison:
			return poison
	return 0.0


func get_tower(skill_type : Utils.SkillType) -> float:
	match skill_type:
		Utils.SkillType.Projectile, Utils.SkillType.Melee:
			return projectile
		Utils.SkillType.Area:
			return area
		Utils.SkillType.Beaming:
			return beam
	return 0.0


## "Poison 40%, Fire 20%, Bolter 30%": the resistances above 0, strongest first; empty with none.
func get_summary() -> String:
	return ", ".join(get_parts().map(func(part : Array) -> String: return "%s %d%%" % [part[0], roundi(part[1] * 100.0)]))


## [name, share, element] for each resistance above 0, strongest first; element is Utils.Element.None for a tower kind.
func get_parts() -> Array[Array]:
	var parts : Array[Array] = []
	for part : Array in [["Physical", physical, Utils.Element.Physical], ["Fire", fire, Utils.Element.Fire], ["Frost", frost, Utils.Element.Frost],
			["Poison", poison, Utils.Element.Poison], ["Bolter", projectile, Utils.Element.None], ["Nova", area, Utils.Element.None], ["Beamer", beam, Utils.Element.None]]:
		if part[1] > 0.0:
			parts.append(part)
	parts.sort_custom(func(a : Array, b : Array) -> bool: return a[1] > b[1])
	return parts


## The share of a hit that gets through: element and tower resistance stack, the total capped at 75%.
static func get_damage_factor(element_resistance : float, tower_resistance : float) -> float:
	var through : float = (1.0 - clampf(element_resistance, 0.0, MAX_RESISTANCE)) * (1.0 - clampf(tower_resistance, 0.0, MAX_RESISTANCE))
	return maxf(through, 1.0 - MAX_RESISTANCE)
