class_name EvolveTree
extends Node

## Holds a building type's gold upgrade data and its ElementEvolveLeaf options; BuildingTypeUpgrades
## offers them in the selection panel and applies them to the selected building (or the whole type, see is_per_type).

signal element_changed(element : Utils.Element)
signal tier_changed(tier : int)

@export var upgrade_data : BuildingUpgradeData = null

var is_visited : bool = true
#every tower starts Physical; this turns true when an element leaf is bought (Physical included)
var is_element_chosen : bool = false
#0 before the element, 1 with it (T1), 2 and 3 after the element's tiers (ElementEvolveLeaf.evolve_tier)
var tier : int = 0 :
	set = _set_tier
var evolve_element : Utils.Element = Utils.Element.Physical :
	set = _set_evolve_element


## An element leaf was bought. Emits element_changed even when the tower stays Physical, so talents that a tower only
## leaned to (LevelTalents) come off.
func choose_element(value : Utils.Element) -> void:
	is_element_chosen = true
	tier = maxi(tier, 1)
	if evolve_element == value:
		element_changed.emit(evolve_element)
	else:
		evolve_element = value


func _set_tier(value : int) -> void:
	if tier == value:
		return

	tier = value
	tier_changed.emit(tier)


func _set_evolve_element(value : Utils.Element) -> void:
	if evolve_element == value:
		return

	evolve_element = value
	element_changed.emit(evolve_element)
