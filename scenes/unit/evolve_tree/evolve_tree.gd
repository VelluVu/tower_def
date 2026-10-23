class_name EvolveTree
extends Node

## Holds a building type's gold upgrade data and its ElementEvolveLeaf options; BuildingTypeUpgrades
## offers them in the selection panel and applies them to every building of the type at once.

signal element_changed(element : Utils.Element)

@export var upgrade_data : BuildingUpgradeData = null

var is_visited : bool = true
var evolve_element : Utils.Element = Utils.Element.Physical :
	set = _set_evolve_element


func _set_evolve_element(value : Utils.Element) -> void:
	if evolve_element == value:
		return

	evolve_element = value
	element_changed.emit(evolve_element)
