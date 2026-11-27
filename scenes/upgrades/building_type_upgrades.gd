class_name BuildingTypeUpgrades
extends Node

## Gold upgrades and element evolves, bought from the selection panel.
## Upgrades and tiers are bought per building, so a new building starts at the base; data with
## is_per_type (walls) upgrades the whole type instead. The element is per building too (the user's
## call 2026-10-27): two Beamers can take different elements.
## Lives under the Level, so everything resets when the level is unloaded.
## The Level creates it before LevelUpgrades, so a new per-type building gets its upgrades before the XP cards check it.

const UPGRADE_TITLE_TEXT : String = "Up %d"
const RANK_TITLE_TEXT : String = "Rank %d"
#a wall's element: bought per wall once the shared wall line is at Up 2 (the design doc's Wall evolves)
const WALL_ELEMENT_MIN_UPGRADES : int = 2
const WALL_ELEMENT_PRICE : float = 2.0
const FORTRESS_TREE : StringName = &"building"
#wall element tiers: T2 at shared Up 4, T3 at Up 6, each behind its tree's wall node, bought once for every wall of the element
const WALL_TIER_UPGRADES : Array[int] = [0, 0, 4, 6]
const WALL_TIER_PRICES : Array[float] = [0.0, 0.0, 8.0, 12.0]
const WALL_TIER_TITLE : String = "%s T%d"
const WALL_TIER_NODES : Dictionary[Utils.Element, Array] = {
	Utils.Element.Physical: [&"building", &"fortress_t2", &"fortress_t3"],
	Utils.Element.Fire: [&"fire", &"fire_wall_t2", &"fire_wall_t3"],
	Utils.Element.Frost: [&"frost", &"wall_t2", &"wall_t3"],
	Utils.Element.Poison: [&"poison", &"wall_t2", &"wall_t3"],
}
const FORTRESS_NODE : StringName = &"fortress_t1"
const WALL_ELEMENTS : Dictionary[Utils.Element, Array] = {
	Utils.Element.Physical: ["Fortress", "res://assets/art/ui/normal_element_icon.png"],
	Utils.Element.Fire: ["Fire wall", "res://assets/art/ui/fire_element_icon.png"],
	Utils.Element.Frost: ["Frost wall", "res://assets/art/ui/frost_element_icon.png"],
	Utils.Element.Poison: ["Poison wall", "res://assets/art/ui/poison_element_icon.png"],
}
const MISSING_ELEMENT_LEAF_WARNING : String = " cannot find element leaf "
#coin gold (Endesga 32): a bought upgrade flashes every building it reaches, as a new one flashes mint
const UPGRADE_FLASH_COLOR : Color = Color("fee761")
const UPGRADE_FLASH_SECONDS : float = 0.3
const UPGRADE_PIPS_NAME : String = "UpgradePips"
const BUFFER_TRACK_TITLE : String = "%s %d/%d"
const BUFFER_MEND_TEXT : String = "Walls in the aura heal %s of their max health a second a pip (now %s); towers and traps a quarter of it, siege attackers halve it. Pips left: %d of %d."
const BUFFER_TRACK_TEXT : String = "Towers and traps in the aura: %s +%s a pip (now +%s). Several Buffers never stack: each stat takes the strongest. Pips left: %d of %d."


class UpgradeState:
	var upgrades_bought : int = 0
	var tiers_evolved : int = 0
	#repeatable ranks after the last step (RankData)
	var ranks : int = 0
	#path from the building to the element leaf it evolved into, empty before the first tier
	var element_leaf_path : NodePath = NodePath()


var type_states : Dictionary[String, UpgradeState] = {}
#element -> the tier every wall of it has (1 until T2 is bought)
var wall_element_tiers : Dictionary[Utils.Element, int] = {}
var building_states : Dictionary[Building, UpgradeState] = {}
#gold spent on each tower's and trap's own upgrades and tiers (Salvage refunds a share of it)
var upgrade_gold : Dictionary[Building, float] = {}
#the rank modifiers on each building, swapped for new ones on every rank
var rank_modifiers : Dictionary[Building, Array] = {}
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
	#a Thrift card changes the prices shown
	GameSignals.upgrade_cards_closed.connect(_on_upgrade_cards_closed)
	UISignals.gold_upgrade_pressed.connect(_on_gold_upgrade_pressed)
	UISignals.target_tactic_selected.connect(_on_target_tactic_selected)
	UISignals.rally_pressed.connect(_on_rally_pressed)


func _on_unit_selected(unit : Node2D) -> void:
	selected_unit = unit
	_emit_options()
	_emit_target_tactic()
	_emit_rally()


func _on_unit_deselected(_unit : Node2D) -> void:
	selected_unit = null
	_emit_options()
	_emit_target_tactic()
	_emit_rally()


#the targeting tactic lives on the tower; this node only knows which tower is selected
#the tower picks its target again every tick, so a change during a wave counts at once
func _on_target_tactic_selected(tactic : Utils.TargetTactic) -> void:
	if selected_unit is Tower and selected_unit.can_choose_target and selected_unit.is_placed:
		selected_unit.target_tactic = tactic
	_emit_target_tactic()


func _emit_target_tactic() -> void:
	var has_tactic : bool = is_instance_valid(selected_unit) and selected_unit is Tower and selected_unit.can_choose_target and selected_unit.is_placed
	UISignals.target_tactic_changed.emit(selected_unit.target_tactic if has_tactic else -1)


func _on_rally_pressed() -> void:
	if is_instance_valid(selected_unit) and selected_unit is Hatchery and selected_unit.is_placed:
		selected_unit.start_rally_pick()


func _emit_rally() -> void:
	UISignals.rally_shown.emit(is_instance_valid(selected_unit) and selected_unit is Hatchery and selected_unit.is_placed)


func _on_building_placed(building : Building) -> void:
	if building == selected_unit:
		_emit_options()

	if not _is_upgradable(building) or not _is_per_type(building) or not type_states.has(building.scene_file_path):
		return

	var state : UpgradeState = type_states[building.scene_file_path]

	if not state.element_leaf_path.is_empty():
		_apply_evolve(building, state.element_leaf_path)

	#per-type buildings (walls) have no element tiers, so no evolved upgrades either
	for i in state.upgrades_bought:
		_apply_upgrade(building, false)
	_apply_ranks(building, state.ranks)

	_update_pips(building, state)
	building.stats_changed.emit()


func _on_building_removed(building : Building) -> void:
	building_states.erase(building)
	rank_modifiers.erase(building)

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

	if option.is_locked or not level.player_stats.spend_gold(option.cost):
		return
	var bought_for : Building = selected_unit as Building
	if not _is_per_type(bought_for):
		upgrade_gold[bought_for] = upgrade_gold.get(bought_for, 0.0) + option.cost

	#a wall element is bought for the selected wall alone and is not a step of the shared wall line
	if option.wall_tier > 0:
		wall_element_tiers[option.wall_element] = option.wall_tier
		for building in level.all_buildings:
			if building is Wall and building.element == option.wall_element:
				building.on_element_tier_changed()
		GameSignals.astar_grid_updated.emit()
		GameSignals.gold_upgrade_bought.emit(selected_unit, true)
		_emit_options()
		return
	if option.wall_element != Utils.Element.None and selected_unit is Wall:
		selected_unit.set_element(option.wall_element)
		GameSignals.gold_upgrade_bought.emit(selected_unit, true)
		_emit_options()
		return

	if option.buffer_stat >= 0 and selected_unit is Buffer:
		_buy_buffer_pip(selected_unit as Buffer, option.buffer_stat)
		return

	var type_key : String = selected_unit.scene_file_path
	var state : UpgradeState = _get_state(selected_unit)

	if option.is_rank:
		state.ranks += 1
	elif option.is_evolve:
		state.tiers_evolved += 1
		if state.element_leaf_path.is_empty():
			state.element_leaf_path = option.element_leaf_path
	else:
		state.upgrades_bought += 1

	var targets : Array[Building] = [selected_unit]
	if _is_per_type(selected_unit):
		targets.clear()
		for building in level.all_buildings:
			if _is_upgradable(building) and building.scene_file_path == type_key:
				targets.append(building)

	for building in targets:
		if option.is_rank:
			_apply_ranks(building, state.ranks)
		elif option.tier > 0:
			_apply_tier(building, option.element_leaf_path, option.tier - 1)
		elif option.is_evolve:
			_apply_evolve(building, option.element_leaf_path)
		else:
			_apply_upgrade(building, state.tiers_evolved > 0)

		_update_pips(building, state)
		building.stats_changed.emit()
		if building.animation_control != null:
			building.animation_control.play_flash(UPGRADE_FLASH_COLOR, UPGRADE_FLASH_SECONDS)

	GameSignals.gold_upgrade_bought.emit(selected_unit, option.is_evolve)
	_emit_options()


func _on_upgrade_cards_closed() -> void:
	if selected_unit != null:
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
	var chosen_leaf : ElementEvolveLeaf = _get_chosen_leaf(building, state)
	#T1 is the element; T2 and T3 are the chosen element's tiers
	var tier_count : int = 0
	if not element_leafs.is_empty():
		tier_count = 1 + (chosen_leaf.tiers.size() if chosen_leaf != null else 0)
	tier_count = mini(data.evolve_cost_ratios.size(), tier_count)
	#the base price: the tower price step makes a late tower dearer, not its upgrades
	var building_price : float = building.stats.get_stat(Utils.StatType.Price).base_value
	var new_options : Array[GoldUpgradeOption] = []
	if building is Buffer:
		return _build_buffer_options(building as Buffer, data, state, element_leafs, chosen_leaf, tier_count, building_price)

	match UpgradeRules.next_gold_step(state.upgrades_bought, state.tiers_evolved, data.upgrade_cost_ratios.size(), tier_count, data.upgrades_before_tier(state.tiers_evolved)):
		UpgradeRules.GoldStep.Upgrade:
			var upgrade_price : float = UpgradeRules.gold_price(building_price, data.upgrade_cost_ratios[state.upgrades_bought] * _price_share() * _first_upgrade_share(building, state))
			var upgrade_option : GoldUpgradeOption = GoldUpgradeOption.upgrade(UPGRADE_TITLE_TEXT % (state.upgrades_bought + 1), data.upgrade_icon, upgrade_price)
			upgrade_option.description = UpgradeTooltipText.for_upgrade(data, state.tiers_evolved > 0)
			new_options.append(upgrade_option)
		UpgradeRules.GoldStep.Evolve:
			var evolve_price : float = UpgradeRules.gold_price(building_price, data.evolve_cost_ratios[state.tiers_evolved] * _price_share())
			if state.tiers_evolved == 0:
				for leaf in element_leafs:
					new_options.append(GoldUpgradeOption.evolve(leaf, building, evolve_price))
			else:
				new_options.append(GoldUpgradeOption.evolve_tier(chosen_leaf, building, state.tiers_evolved - 1, evolve_price))

	#a plain wall can take an element once the shared wall line is at Up 2
	if building is Wall and building.element == Utils.Element.None and state.upgrades_bought >= WALL_ELEMENT_MIN_UPGRADES:
		for element in WALL_ELEMENTS:
			#Fortress waits for its Building tree node; the other elements have no talent lock at T1
			if element == Utils.Element.Physical and PlayerProgress.get_talent_ranks(FORTRESS_TREE).get(FORTRESS_NODE, 0) <= 0:
				continue
			var element_option : GoldUpgradeOption = GoldUpgradeOption.wall_element_option(element, WALL_ELEMENTS[element][0], load(WALL_ELEMENTS[element][1]), WALL_ELEMENT_PRICE)
			element_option.description = UpgradeTooltipText.for_wall_element(element)
			new_options.append(element_option)

	#an element wall: its element's next tier once the shared line is far enough (locked until its tree node)
	if building is Wall and building.element != Utils.Element.None:
		var next_tier : int = get_wall_tier(building.element) + 1
		if next_tier <= 3 and state.upgrades_bought >= WALL_TIER_UPGRADES[next_tier]:
			var tier_option : GoldUpgradeOption = GoldUpgradeOption.wall_element_option(building.element, WALL_TIER_TITLE % [WALL_ELEMENTS[building.element][0], next_tier], load(WALL_ELEMENTS[building.element][1]), WALL_TIER_PRICES[next_tier])
			tier_option.wall_tier = next_tier
			var nodes : Array = WALL_TIER_NODES[building.element]
			tier_option.is_locked = PlayerProgress.get_talent_ranks(nodes[0]).get(nodes[next_tier - 1], 0) <= 0
			tier_option.description = UpgradeTooltipText.for_wall_tier(building.element, WALL_ELEMENTS[building.element][0], next_tier, tier_option.is_locked)
			new_options.append(tier_option)

	var rank_option : GoldUpgradeOption = _rank_option(building, data, state, new_options, building_price)
	if rank_option != null:
		new_options.append(rank_option)

	for option in new_options:
		option.is_affordable = not option.is_locked and level.player_stats.has_enough_gold(option.cost)

	return new_options


## The next rank, once nothing else on the building's own line can be bought: every step is bought, or the next is
## a tier its talent node has not opened. Element choices of a wall do not count (they are bought per wall).
func _rank_option(building : Building, data : BuildingUpgradeData, state : UpgradeState, line_options : Array[GoldUpgradeOption],
		building_price : float) -> GoldUpgradeOption:
	var ranks : RankData = data.rank_data
	if ranks == null or ranks.steps.is_empty() or state.ranks >= ranks.get_max_ranks():
		return null
	for option in line_options:
		if not option.is_locked and option.wall_element == Utils.Element.None:
			return null
	var price : float = UpgradeRules.gold_price(building_price, ranks.get_cost_ratio(state.ranks) * _price_share())
	var option : GoldUpgradeOption = GoldUpgradeOption.upgrade(RANK_TITLE_TEXT % (state.ranks + 1), data.upgrade_icon, price)
	option.is_rank = true
	option.description = UpgradeTooltipText.for_rank(ranks, state.ranks, _is_per_type(building))
	return option


## Swaps the building's rank modifiers for ones worth ranks ranks (each step capped).
func _apply_ranks(building : Building, ranks : int) -> void:
	var data : BuildingUpgradeData = building.evolve_tree.upgrade_data
	if data.rank_data == null:
		return
	var missing_health : float = building.stats.get_stat_value(Utils.StatType.MaxHealth) - building.stats.get_stat_value(Utils.StatType.Health)
	for modifier : ModifierData in rank_modifiers.get(building, []):
		building.modifier_manager.remove_modifier(modifier)
	var modifiers : Array[ModifierData] = []
	if ranks > 0:
		for index in data.rank_data.steps.size():
			var modifier : ModifierData = data.rank_data.steps[index].get_modifier_data()
			modifier.value = data.rank_data.get_total(index, ranks)
			building.modifier_manager.add_modifier(modifier)
			modifiers.append(modifier)
	rank_modifiers[building] = modifiers
	var health : Stat = building.stats.get_stat(Utils.StatType.Health)
	if health != null:
		health.value = building.stats.get_stat_value(Utils.StatType.MaxHealth) - missing_health


## A Buffer: one button per track that has room (pips from the budget, the price rising with every pip), and the
## element (after 2 pips), T2 (after 5) and T3 (after 8) next to them; pips never wait for a tier.
func _build_buffer_options(buffer : Buffer, data : BuildingUpgradeData, state : UpgradeState, element_leafs : Array[ElementEvolveLeaf],
		chosen_leaf : ElementEvolveLeaf, tier_count : int, building_price : float) -> Array[GoldUpgradeOption]:
	var new_options : Array[GoldUpgradeOption] = []
	var total : int = buffer.total_pips
	if total < buffer.pip_budget:
		var pip_price : float = UpgradeRules.gold_price(building_price, Buffer.PIP_COST_RATIOS[mini(total, Buffer.PIP_COST_RATIOS.size() - 1)] * _price_share())
		for stat in Buffer.TRACKS:
			if not buffer.can_add_pip(stat):
				continue
			var pips : int = buffer.get_pips(stat)
			var option : GoldUpgradeOption = GoldUpgradeOption.upgrade(BUFFER_TRACK_TITLE % [Buffer.TRACK_NAMES[stat], pips, Buffer.MAX_PIPS],
				load(Buffer.TRACK_ICONS[stat]), pip_price)
			option.buffer_stat = stat
			if stat == Utils.StatType.WallMend:
				option.description = BUFFER_MEND_TEXT % [_buff_text(stat, float(Buffer.PIP_VALUES[stat][1])), _buff_text(stat, buffer.get_mend_rate()),
					buffer.pip_budget - total, buffer.pip_budget]
			else:
				option.description = BUFFER_TRACK_TEXT % [Buffer.TRACK_NAMES[stat].to_lower(), _buff_text(stat, float(Buffer.PIP_VALUES[stat][1])),
					_buff_text(stat, buffer.get_buff(stat)), buffer.pip_budget - total, buffer.pip_budget]
			new_options.append(option)
	if state.tiers_evolved < tier_count and total >= data.upgrades_before_tier(state.tiers_evolved):
		var evolve_price : float = UpgradeRules.gold_price(building_price, data.evolve_cost_ratios[state.tiers_evolved] * _price_share())
		if state.tiers_evolved == 0:
			for leaf in element_leafs:
				new_options.append(GoldUpgradeOption.evolve(leaf, buffer, evolve_price))
		else:
			new_options.append(GoldUpgradeOption.evolve_tier(chosen_leaf, buffer, state.tiers_evolved - 1, evolve_price))
	for option in new_options:
		option.is_affordable = not option.is_locked and level.player_stats.has_enough_gold(option.cost)
	return new_options


#"6%" for a damage pip, "0.04" for attack speed, "0.1 tiles" for range
static func _buff_text(stat : Utils.StatType, value : float) -> String:
	match stat:
		Utils.StatType.Damage, Utils.StatType.EffectPotency:
			return "%d%%" % roundi(value * 100.0)
		Utils.StatType.CriticalChance:
			return "%d points" % roundi(value * 100.0)
		Utils.StatType.AttackRange:
			return "%s tiles" % String.num(value, 2)
		Utils.StatType.WallMend:
			return "%s%%" % String.num(value * 100.0, 1)
	return String.num(value, 2)


func _buy_buffer_pip(buffer : Buffer, stat : Utils.StatType) -> void:
	buffer.add_pip(stat)
	var state : UpgradeState = _get_state(buffer)
	state.upgrades_bought += 1
	_update_pips(buffer, state)
	buffer.stats_changed.emit()
	if buffer.animation_control != null:
		buffer.animation_control.play_flash(UPGRADE_FLASH_COLOR, UPGRADE_FLASH_SECONDS)
	GameSignals.gold_upgrade_bought.emit(buffer, false)
	_emit_options()


#Hoard (talent): the first upgrade of each tower and trap is cheaper
func _first_upgrade_share(building : Building, state : UpgradeState) -> float:
	if level.talents == null or _is_per_type(building) or state.upgrades_bought > 0:
		return 1.0
	return 1.0 - level.talents.get_total(TalentEffect.Kind.FirstUpgradeDiscount)


#Haggling (talent) and Thrift (card): the share of the price left
func _price_share() -> float:
	var discount : float = level.talents.get_total(TalentEffect.Kind.UpgradeDiscount) if level.talents != null else 0.0
	if level.upgrades != null:
		discount += level.upgrades.upgrade_discount
	return 1.0 - minf(discount, LevelUpgrades.MAX_UPGRADE_DISCOUNT)


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


func _apply_tier(building : Building, leaf_path : NodePath, tier_index : int) -> void:
	var leaf : ElementEvolveLeaf = building.get_node_or_null(leaf_path) as ElementEvolveLeaf

	if leaf == null:
		push_warning(building.name, MISSING_ELEMENT_LEAF_WARNING, leaf_path)
		return

	leaf.evolve_tier(building, tier_index)
	building.evolve_level_up_particle_effect.emitting = true


func _get_chosen_leaf(building : Building, state : UpgradeState) -> ElementEvolveLeaf:
	if state.element_leaf_path.is_empty():
		return null
	return building.get_node_or_null(state.element_leaf_path) as ElementEvolveLeaf


func _update_pips(building : Building, state : UpgradeState) -> void:
	var pips : UpgradePips = building.get_node_or_null(UPGRADE_PIPS_NAME) as UpgradePips

	if pips == null:
		pips = UpgradePips.new()
		pips.name = UPGRADE_PIPS_NAME
		building.add_child(pips)

	var tier_color : Color = Color.WHITE
	var leaf : ElementEvolveLeaf = building.get_node_or_null(state.element_leaf_path) as ElementEvolveLeaf if not state.element_leaf_path.is_empty() else null
	if leaf != null:
		tier_color = leaf.evolve_glow_color

	#the upgrades bought before a tier are shown by its tier pip
	var data : BuildingUpgradeData = building.evolve_tree.upgrade_data
	var upgrades_at_last_tier : int = data.upgrades_before_tier(state.tiers_evolved - 1) if state.tiers_evolved > 0 else 0
	var upgrades_since_tier : int = maxi(0, state.upgrades_bought - upgrades_at_last_tier)
	pips.set_steps(upgrades_since_tier, state.tiers_evolved, tier_color)

	if building is Wall:
		(building as Wall).set_upgrade_stage(state.upgrades_bought)


## The tier every wall of an element has: 1, or 2 and 3 once bought.
func get_wall_tier(element : Utils.Element) -> int:
	return wall_element_tiers.get(element, 1)


## Gold upgrades and tiers bought for the building (the Dragonslayer cleaves the most upgraded tower).
func get_upgrade_steps(building : Building) -> int:
	if not _is_upgradable(building):
		return 0
	#read only: never make a state for a building nothing was bought for
	var state : UpgradeState = type_states.get(building.scene_file_path) if _is_per_type(building) else building_states.get(building)
	return state.upgrades_bought + state.tiers_evolved + state.ranks if state != null else 0


## Ranks bought for the building (per type for walls).
func get_ranks(building : Building) -> int:
	if not _is_upgradable(building):
		return 0
	var state : UpgradeState = type_states.get(building.scene_file_path) if _is_per_type(building) else building_states.get(building)
	return state.ranks if state != null else 0


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
