class_name EvolveTree
extends Node

## Holds a building type's gold upgrade data and its ElementEvolveLeaf options; BuildingTypeUpgrades
## offers them in the selection panel and applies them to the selected building (or the whole type, see is_per_type).

signal element_changed(element : Utils.Element)

@export var upgrade_data : BuildingUpgradeData = null

var is_visited : bool = true
#every tower starts Physical; this turns true when an element leaf is bought (Physical included)
var is_element_chosen : bool = false
var evolve_element : Utils.Element = Utils.Element.Physical :
	set = _set_evolve_element


## An element leaf was bought. Emits element_changed even when the tower stays Physical, so talents that a tower only
## leaned to (LevelTalents) come off.
func choose_element(value : Utils.Element) -> void:
	is_element_chosen = true
	if evolve_element == value:
		element_changed.emit(evolve_element)
	else:
		evolve_element = value


func _set_evolve_element(value : Utils.Element) -> void:
	if evolve_element == value:
		return

	evolve_element = value
	element_changed.emit(evolve_element)
