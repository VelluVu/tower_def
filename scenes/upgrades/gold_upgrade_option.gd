class_name GoldUpgradeOption
extends RefCounted

## One button in the selection panel: the next gold upgrade of a building type,
## or one element at an evolve step.

const LOCKED_TEXT : String = "%s needs %s in the %s tree"

var title : String = ""
#what it gives, the tooltip's body under the title (UpgradeTooltipText)
var description : String = ""
var icon : Texture2D = null
var cost : float = 0.0
var is_affordable : bool = false
var element_leaf_path : NodePath = NodePath()
#0 = the element (T1); 1 = T2, 2 = T3 of the leaf at element_leaf_path
var tier : int = 0
#a tier whose talent node is not learned: shown, never bought
var is_locked : bool = false

#a wall's element for the selected wall only (Utils.Element); None for every other option
var wall_element : Utils.Element = Utils.Element.None
#a wall element tier (2 or 3) for every wall of wall_element; 0 for every other option
var wall_tier : int = 0
#a Buffer's pip on this track (Utils.StatType); -1 for every other option
var buffer_stat : int = -1

var is_evolve : bool :
	get:
		return not element_leaf_path.is_empty()

#one of several elements to pick from (a tower's T1 or a wall's element): the player decides, a shortcut never buys it
var is_choice : bool :
	get:
		return (is_evolve and tier == 0) or wall_element != Utils.Element.None


static func wall_element_option(element : Utils.Element, _title : String, _icon : Texture2D, _cost : float) -> GoldUpgradeOption:
	var option : GoldUpgradeOption = upgrade(_title, _icon, _cost)
	option.wall_element = element
	return option


static func upgrade(_title : String, _icon : Texture2D, _cost : float) -> GoldUpgradeOption:
	var option : GoldUpgradeOption = GoldUpgradeOption.new()
	option.title = _title
	option.icon = _icon
	option.cost = _cost
	return option


static func evolve(leaf : ElementEvolveLeaf, building : Building, _cost : float) -> GoldUpgradeOption:
	var option : GoldUpgradeOption = GoldUpgradeOption.new()
	option.title = leaf.info
	option.description = UpgradeTooltipText.for_element(leaf)
	option.icon = leaf.icon
	option.cost = _cost
	option.element_leaf_path = building.get_path_to(leaf)
	return option


static func evolve_tier(leaf : ElementEvolveLeaf, building : Building, tier_index : int, _cost : float) -> GoldUpgradeOption:
	var data : EvolveTierData = leaf.tiers[tier_index]
	var option : GoldUpgradeOption = GoldUpgradeOption.new()
	option.title = data.title
	option.icon = data.icon if data.icon != null else leaf.icon
	option.cost = _cost
	option.element_leaf_path = building.get_path_to(leaf)
	option.tier = tier_index + 1
	option.is_locked = not data.is_unlocked()
	if option.is_locked:
		option.title = LOCKED_TEXT % [data.title, TalentRules.get_node_name(data.talent_tree, data.talent_node), data.talent_tree.capitalize()]
	option.description = UpgradeTooltipText.for_tier(data, option.is_locked)
	return option
