class_name GoldUpgradeOption
extends RefCounted

## One button in the selection panel: the next gold upgrade of a building type,
## or one element at an evolve step.

var title : String = ""
var icon : Texture2D = null
var cost : float = 0.0
var is_affordable : bool = false
var element_leaf_path : NodePath = NodePath()

var is_evolve : bool :
	get:
		return not element_leaf_path.is_empty()


static func upgrade(_title : String, _icon : Texture2D, _cost : float) -> GoldUpgradeOption:
	var option : GoldUpgradeOption = GoldUpgradeOption.new()
	option.title = _title
	option.icon = _icon
	option.cost = _cost
	return option


static func evolve(leaf : ElementEvolveLeaf, building : Building, _cost : float) -> GoldUpgradeOption:
	var option : GoldUpgradeOption = GoldUpgradeOption.new()
	option.title = leaf.info
	option.icon = leaf.icon
	option.cost = _cost
	option.element_leaf_path = building.get_path_to(leaf)
	return option
