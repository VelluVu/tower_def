class_name EvolveTree
extends Node

## Holds a building type's gold upgrade data and its ElementEvolveLeaf options; BuildingTypeUpgrades
## offers them in the selection panel and applies them to every building of the type at once.

@export var upgrade_data : BuildingUpgradeData = null

var is_visited : bool = true
var evolve_element : Utils.Element = Utils.Element.Physical
