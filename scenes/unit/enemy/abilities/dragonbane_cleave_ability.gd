class_name DragonbaneCleaveAbility
extends MultiStrikeAbility

## The Dragonslayer's cleave: a blow that stuns the most upgraded tower in reach (gold upgrades and
## tiers bought; the nearest one on a tie). It hurts and silences rather than kills, so investing
## in a tower is not punished by losing it.


func _is_picked_before(a : Building, b : Building) -> bool:
	var upgrades : BuildingTypeUpgrades = enemy.level.building_type_upgrades
	var a_steps : int = upgrades.get_upgrade_steps(a) if upgrades != null else 0
	var b_steps : int = upgrades.get_upgrade_steps(b) if upgrades != null else 0

	if a_steps != b_steps:
		return a_steps > b_steps
	return super(a, b)
