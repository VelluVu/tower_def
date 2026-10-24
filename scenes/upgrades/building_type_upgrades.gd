class_name BuildingTypeUpgrades
extends Node

## Gold upgrades and element evolves, bought from the selection panel.
## Upgrades and tiers are bought per building, so a new building starts at the base; data with
## is_per_type (walls) upgrades the whole type instead. The element is per type: the first building
## of a type to evolve picks it, the others of the type can then only evolve into it.
## Lives under the Level, so everything resets when the level is unloaded.
## The Level creates it before LevelUpgrades, so a new per-type building gets its element before the XP cards check it.

const UPGRADE_TITLE_TEXT : String = "Up %d"
const MISSING_ELEMENT_LEAF_WARNING : String = " cannot find element leaf "
const UPGRADE_PIPS_NAME : String = "UpgradePips"


class UpgradeState:
	var upgrades_bought : int = 0
	var tiers_evolved : int = 0


var type_states : Dictionary[String, UpgradeState] = {}
var building_states : Dictionary[Building, UpgradeState] = {}
#scene path -> the element leaf the type evolved into first
var type_elements : Dictionary[String, NodePath] = {}
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

	if not _is_upgradable(building) or not _is_per_type(building) or not type_states.has(building.scene_file_path):
		return

	var state : UpgradeState = type_states[building.scene_file_path]

	if type_elements.has(building.scene_file_path):
		_apply_evolve(building, type_elements[building.scene_file_path])

	#per-type buildings (walls) have no element tiers, so no evolved upgrades either
	for i in state.upgrades_bought:
		_apply_upgrade(building, false)

	_update_pips(building, state)
	building.stats_changed.emit()


func _on_building_removed(building : Building) -> void:
	building_states.erase(building)

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
	var state : UpgradeState = _get_state(selected_unit)

	if option.is_evolve:
		state.tiers_evolved += 1
		if not type_elements.has(type_key):
			type_elements[type_key] = option.element_leaf_path
	else:
		state.upgrades_bought += 1

	var targets : Array[Building] = [selected_unit]
	if _is_per_type(selected_unit):
		targets.clear()
		for building in level.all_buildings:
			if _is_upgradable(building) and building.scene_file_path == type_key:
				targets.append(building)

	for building in targets:
		if option.is_evolve:
			_apply_evolve(building, option.element_leaf_path)
		else:
			_apply_upgrade(building, state.tiers_evolved > 0)

		_update_pips(building, state)
		building.stats_changed.emit()

	GameSignals.gold_upgrade_bought.emit(selected_unit, option.is_evolve)
	_emit_options()


func _emit_options() -> void:
	options.clear()
	
	if _is_selected_upgradable():
		options = _build_options()
	
	UISignals.gold_upgrades_changed.emit(options)


func _build_options() -> Array[GoldUpgradeOption]:
	var building : Building = selected_unit
	var data : BuildingUpgradeData = building.evolve_tree.upgrade_data
	var state : UpgradeState = _get_state(building)
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
				if type_elements.has(building.scene_file_path) and building.get_path_to(leaf) != type_elements[building.scene_file_path]:
					continue
				new_options.append(GoldUpgradeOption.evolve(leaf, building, evolve_price))

	for option in new_options:
		option.is_affordable = level.player_stats.has_enough_gold(option.cost)

	return new_options


func _apply_upgrade(building : Building, is_evolved : bool) -> void:
	#Health is not modified with MaxHealth, so keep the damage taken and add the new max on top
	var missing_health : float = building.stats.get_stat_value(Utils.StatType.MaxHealth) - building.stats.get_stat_value(Utils.StatType.Health)
	var data : BuildingUpgradeData = building.evolve_tree.upgrade_data

	for resource in data.upgrade_resources:
		building.modifier_manager.add_modifier(resource.get_modifier_data())

	if is_evolved:
		for resource in data.evolved_upgrade_resources:
			building.modifier_manager.add_modifier(resource.get_modifier_data())

	var health : Stat = building.stats.get_stat(Utils.StatType.Health)
	if health != null:
		health.value = building.stats.get_stat_value(Utils.StatType.MaxHealth) - missing_health


func _apply_evolve(building : Building, leaf_path : NodePath) -> void:
	var leaf : ElementEvolveLeaf = building.get_node_or_null(leaf_path) as ElementEvolveLeaf

	if leaf == null:
		push_warning(building.name, MISSING_ELEMENT_LEAF_WARNING, leaf_path)
		return

	leaf.evolve(building)
	building.evolve_level_up_particle_effect.emitting = true


func _update_pips(building : Building, state : UpgradeState) -> void:
	var pips : UpgradePips = building.get_node_or_null(UPGRADE_PIPS_NAME) as UpgradePips

	if pips == null:
		pips = UpgradePips.new()
		pips.name = UPGRADE_PIPS_NAME
		building.add_child(pips)

	var tier_color : Color = Color.WHITE
	var leaf : ElementEvolveLeaf = building.get_node_or_null(type_elements.get(building.scene_file_path, NodePath())) as ElementEvolveLeaf
	if leaf != null:
		tier_color = leaf.evolve_glow_color

	#the upgrades bought before a tier are shown by its tier pip
	var upgrades_since_tier : int = maxi(0, state.upgrades_bought - state.tiers_evolved * building.evolve_tree.upgrade_data.upgrades_per_tier)
	pips.set_steps(upgrades_since_tier, state.tiers_evolved, tier_color)


func _get_state(building : Building) -> UpgradeState:
	if _is_per_type(building):
		if not type_states.has(building.scene_file_path):
			type_states[building.scene_file_path] = UpgradeState.new()
		return type_states[building.scene_file_path]

	if not building_states.has(building):
		building_states[building] = UpgradeState.new()
	return building_states[building]


func _is_per_type(building : Building) -> bool:
	return building.evolve_tree.upgrade_data.is_per_type


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
