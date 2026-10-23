class_name BuildingTypeUpgrades
extends Node

## Gold upgrades and element evolves for whole building types, bought from the selection panel.
## Lives under the Level, so everything resets when the level is unloaded.
## The Level creates it before LevelUpgrades, so a new building gets its element before the XP cards check it.

const UPGRADE_TITLE_TEXT : String = "Up %d"
const MISSING_ELEMENT_LEAF_WARNING : String = " cannot find element leaf "


class TypeState:
	var upgrades_bought : int = 0
	var tiers_evolved : int = 0
	var element_leaf_path : NodePath = NodePath()


var states : Dictionary[String, TypeState] = {}
var selected_unit : Node2D = null
var options : Array[GoldUpgradeOption] = []

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level


func _ready() -> void:
	GameSignals.selected_unit.connect(_on_unit_selected)
	GameSignals.deselected_unit.connect(_on_unit_deselected)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_removed)
	GameSignals.building_destroyed.connect(_on_building_removed)
	GameSignals.resource_change.connect(_on_resource_change)
	UISignals.gold_upgrade_pressed.connect(_on_gold_upgrade_pressed)


func _on_unit_selected(unit : Node2D) -> void:
	selected_unit = unit
	_emit_options()


func _on_unit_deselected(_unit : Node2D) -> void:
	selected_unit = null
	_emit_options()


func _on_building_placed(building : Building) -> void:
	if building == selected_unit:
		_emit_options()

	if not _is_upgradable(building) or not states.has(building.scene_file_path):
		return

	var state : TypeState = states[building.scene_file_path]

	if not state.element_leaf_path.is_empty():
		_apply_evolve(building, state.element_leaf_path)

	for i in state.upgrades_bought:
		_apply_upgrade(building)

	building.stats_changed.emit()


func _on_building_removed(building : Building) -> void:
	if building != selected_unit:
		return

	selected_unit = null
	_emit_options()


func _on_resource_change(_value : int, resource_index : int) -> void:
	#gold changes which buttons are affordable
	if resource_index == 0 and selected_unit != null:
		_emit_options()


func _on_gold_upgrade_pressed(index : int) -> void:
	if index < 0 or index >= options.size() or not _is_selected_upgradable():
		return

	var option : GoldUpgradeOption = options[index]

	if not level.player_stats.spend_gold(option.cost):
		return

	var type_key : String = selected_unit.scene_file_path
	var state : TypeState = _get_state(type_key)

	if option.is_evolve:
		state.tiers_evolved += 1
		state.element_leaf_path = option.element_leaf_path
	else:
		state.upgrades_bought += 1

	for building in level.all_buildings:
		if not _is_upgradable(building) or building.scene_file_path != type_key:
			continue

		if option.is_evolve:
			_apply_evolve(building, option.element_leaf_path)
		else:
			_apply_upgrade(building)

		building.stats_changed.emit()

	_emit_options()


func _emit_options() -> void:
	options.clear()
	
	if _is_selected_upgradable():
		options = _build_options()
	
	UISignals.gold_upgrades_changed.emit(options)


func _build_options() -> Array[GoldUpgradeOption]:
	var building : Building = selected_unit
	var data : BuildingUpgradeData = building.evolve_tree.upgrade_data
	var state : TypeState = _get_state(building.scene_file_path)
	var element_leafs : Array[ElementEvolveLeaf] = _get_element_leafs(building)
	#only the T1 element leaves exist so far, later tiers stay locked
	var tier_count : int = mini(data.evolve_cost_ratios.size(), 0 if element_leafs.is_empty() else 1)
	var building_price : float = building.stats.get_stat_value(Utils.StatType.Price)
	var new_options : Array[GoldUpgradeOption] = []

	match UpgradeRules.next_gold_step(state.upgrades_bought, state.tiers_evolved, data.upgrade_cost_ratios.size(), tier_count, data.upgrades_per_tier):
		UpgradeRules.GoldStep.Upgrade:
			var upgrade_price : float = UpgradeRules.gold_price(building_price, data.upgrade_cost_ratios[state.upgrades_bought])
			new_options.append(GoldUpgradeOption.upgrade(UPGRADE_TITLE_TEXT % (state.upgrades_bought + 1), data.upgrade_icon, upgrade_price))
		UpgradeRules.GoldStep.Evolve:
			var evolve_price : float = UpgradeRules.gold_price(building_price, data.evolve_cost_ratios[state.tiers_evolved])
			for leaf in element_leafs:
				new_options.append(GoldUpgradeOption.evolve(leaf, building, evolve_price))

	for option in new_options:
		option.is_affordable = level.player_stats.has_enough_gold(option.cost)

	return new_options


func _apply_upgrade(building : Building) -> void:
	for resource in building.evolve_tree.upgrade_data.upgrade_resources:
		building.modifier_manager.add_modifier(resource.get_modifier_data())


func _apply_evolve(building : Building, leaf_path : NodePath) -> void:
	var leaf : ElementEvolveLeaf = building.get_node_or_null(leaf_path) as ElementEvolveLeaf

	if leaf == null:
		push_warning(building.name, MISSING_ELEMENT_LEAF_WARNING, leaf_path)
		return

	leaf.evolve(building)
	building.evolve_level_up_particle_effect.emitting = true


func _get_state(type_key : String) -> TypeState:
	if not states.has(type_key):
		states[type_key] = TypeState.new()
	return states[type_key]


func _is_selected_upgradable() -> bool:
	return selected_unit is Building and _is_upgradable(selected_unit) and selected_unit.is_placed


func _is_upgradable(building : Building) -> bool:
	return is_instance_valid(building) and building.evolve_tree != null and building.evolve_tree.upgrade_data != null


func _get_element_leafs(building : Building) -> Array[ElementEvolveLeaf]:
	var leafs : Array[ElementEvolveLeaf] = []
	_collect_element_leafs(building.evolve_tree, leafs)
	return leafs


func _collect_element_leafs(node : Node, leafs : Array[ElementEvolveLeaf]) -> void:
	for child in node.get_children():
		if child is ElementEvolveLeaf:
			leafs.append(child)
		_collect_element_leafs(child, leafs)
