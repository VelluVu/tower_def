class_name LevelUpgrades
extends Node

## Level-wide upgrades: one XP bar fed by every kill, and the chosen cards applied to every tower.
## Lives under the Level, so everything resets when the level is unloaded.

const CARD_COUNT : int = 4
const NO_CARDS_WARNING : String = " no upgrade cards fit the placed towers, skipping level "
const MIXED_MODIFY_TYPE_WARNING : String = " cards of one stat should share a modify type, this one is added as the first card's: "
const CARD_CAPS : CardCaps = preload("res://scenes/upgrades/card_caps.tres")

var xp : float = 0.0
var upgrade_level : int = 1
var pending_level_ups : int = 0
var is_finished : bool = false
var offered_cards : Array[UpgradeCard]
var chosen_cards : Array[UpgradeCard]
#the capped total of the chosen XP cards, added to the XP of every kill
var xp_bonus : float = 0.0
#building -> {Utils.StatType: ModifierData}: one capped modifier per stat sums the cards that fit the building
var applied_modifiers : Dictionary[Building, Dictionary] = {}

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level

var xp_needed : float :
	get:
		return UpgradeRules.xp_required(upgrade_level + pending_level_ups)


func _ready() -> void:
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_removed)
	GameSignals.building_destroyed.connect(_on_building_removed)
	GameSignals.level_completed.connect(_on_level_finished)
	GameSignals.lose_game.connect(_on_level_finished)
	UISignals.upgrade_card_selected.connect(_on_upgrade_card_selected)
	UISignals.game_play_interface_loaded.connect(_emit_xp_changed)


func add_xp(amount : float) -> void:
	if is_finished:
		return

	xp += amount

	while xp >= xp_needed:
		xp -= xp_needed
		pending_level_ups += 1

	_emit_xp_changed()

	if offered_cards.is_empty() and pending_level_ups > 0:
		_offer_next_cards()


func _on_enemy_destroyed(enemy : Enemy) -> void:
	add_xp(UpgradeRules.kill_xp(enemy.stats.get_stat_value(Utils.StatType.MaxHealth), enemy.xp_multiplier) * (1.0 + xp_bonus))


func _on_level_finished(_level : Level = null) -> void:
	is_finished = true


func _on_building_placed(building : Building) -> void:
	if not _is_upgradable(building):
		return

	#a new building has no element yet (walls get their type upgrades first), element changes refit the cards
	building.evolve_tree.element_changed.connect(_on_element_changed.bind(building))
	_refresh_cards(building)


func _on_building_removed(building : Building) -> void:
	applied_modifiers.erase(building)


#a card that fit the old element comes off, a chosen card that fits the new one goes on
func _on_element_changed(_element : Utils.Element, building : Building) -> void:
	_refresh_cards(building)


func _on_upgrade_card_selected(index : int) -> void:
	if index < 0 or index >= offered_cards.size():
		return

	var card : UpgradeCard = offered_cards[index]
	offered_cards.clear()
	upgrade_level += 1
	pending_level_ups -= 1

	chosen_cards.append(card)

	if card.resource.card_target == EvolveResource.CardTarget.Gold:
		level.player_stats.add_gold(card.value)
	elif card.resource.card_target == EvolveResource.CardTarget.Xp:
		xp_bonus = UpgradeRules.capped_bonus(_get_xp_card_total(), CARD_CAPS.xp_soft_cap, CARD_CAPS.xp_hard_cap)
	else:
		for building in _get_upgradable_buildings():
			_refresh_cards(building)

	_emit_xp_changed()
	_offer_next_cards()


func _offer_next_cards() -> void:
	while pending_level_ups > 0 and not is_finished:
		var new_level : int = upgrade_level + 1
		var cards : Array[UpgradeCard] = _get_stat_cards(new_level)

		if not cards.is_empty():
			offered_cards = cards
			GameSignals.game_pause.emit(true)
			GameSignals.upgrade_level_gained.emit(new_level, cards)
			return

		push_warning(name, NO_CARDS_WARNING, new_level)
		upgrade_level += 1
		pending_level_ups -= 1

	GameSignals.upgrade_cards_closed.emit()
	GameSignals.game_pause.emit(false)


func _get_stat_cards(new_level : int) -> Array[UpgradeCard]:
	var pool : Array[EvolveResource] = []

	for resource in RandomEvolveResourceCollection.all_evolve_resources:
		if _can_offer(resource, new_level):
			pool.append(resource)

	pool.shuffle()
	var cards : Array[UpgradeCard] = []

	for resource in pool.slice(0, CARD_COUNT):
		var card : UpgradeCard = UpgradeCard.from_resource(resource, UpgradeRules.roll_value(resource, randf()))
		card.is_past_soft_cap = _is_past_soft_cap(resource, new_level)
		cards.append(card)

	return cards


#a card is left out once it has been picked max_picks times, or when every building it fits is at the hard cap
func _can_offer(resource : EvolveResource, new_level : int) -> bool:
	if resource.max_picks > 0 and chosen_cards.filter(func(card : UpgradeCard) -> bool: return card.resource == resource).size() >= resource.max_picks:
		return false

	if resource.card_target == EvolveResource.CardTarget.Gold:
		return true

	if resource.card_target == EvolveResource.CardTarget.Xp:
		return xp_bonus < CARD_CAPS.xp_hard_cap

	var cap : StatCap = CARD_CAPS.get_cap(resource.modify_stat_type)

	for building in _get_upgradable_buildings():
		if not _fits(resource, building, new_level):
			continue

		if cap == null or UpgradeRules.capped_bonus(_get_card_total(building, resource.modify_stat_type), cap.soft_cap, cap.hard_cap) < cap.hard_cap:
			return true

	return false


func _is_past_soft_cap(resource : EvolveResource, new_level : int) -> bool:
	if resource.card_target == EvolveResource.CardTarget.Xp:
		return _get_xp_card_total() >= CARD_CAPS.xp_soft_cap

	var cap : StatCap = CARD_CAPS.get_cap(resource.modify_stat_type)

	if cap == null or resource.card_target != EvolveResource.CardTarget.Buildings:
		return false

	for building in _get_upgradable_buildings():
		if _fits(resource, building, new_level) and _get_card_total(building, resource.modify_stat_type) >= cap.soft_cap:
			return true

	return false


## Puts one capped modifier per stat on the building for the chosen cards that fit it.
func _refresh_cards(building : Building) -> void:
	#Health is not modified with MaxHealth, so keep the damage taken and add the new max on top
	var missing_health : float = building.stats.get_stat_value(Utils.StatType.MaxHealth) - building.stats.get_stat_value(Utils.StatType.Health)

	for modifier in applied_modifiers.get(building, {}).values():
		building.modifier_manager.remove_modifier(modifier)

	var modifiers : Dictionary[Utils.StatType, ModifierData] = _sum_cards(building)

	for stat_type in modifiers:
		var cap : StatCap = CARD_CAPS.get_cap(stat_type)

		if cap != null:
			modifiers[stat_type].value = UpgradeRules.capped_bonus(modifiers[stat_type].value, cap.soft_cap, cap.hard_cap)

		building.modifier_manager.add_modifier(modifiers[stat_type])

	applied_modifiers[building] = modifiers

	var health : Stat = building.stats.get_stat(Utils.StatType.Health)
	if health != null:
		health.value = building.stats.get_stat_value(Utils.StatType.MaxHealth) - missing_health

	building.stats_changed.emit()


#one uncapped modifier per stat; it goes on the unit stat, which ModifierManager.combine adds to the skill stat
func _sum_cards(building : Building) -> Dictionary[Utils.StatType, ModifierData]:
	var modifiers : Dictionary[Utils.StatType, ModifierData] = {}

	for card in chosen_cards:
		if not _fits(card.resource, building, upgrade_level):
			continue

		var stat_type : Utils.StatType = card.resource.modify_stat_type

		if not modifiers.has(stat_type):
			modifiers[stat_type] = card.get_modifier_data()
			modifiers[stat_type].modifier_type = Utils.ModifierType.StatModifier
			continue

		if modifiers[stat_type].calculate_type != card.resource.modify_type:
			push_warning(name, MIXED_MODIFY_TYPE_WARNING, card.title)

		modifiers[stat_type].value += card.value

	return modifiers


func _get_card_total(building : Building, stat_type : Utils.StatType) -> float:
	var total : float = 0.0

	for card in chosen_cards:
		if card.resource.modify_stat_type == stat_type and _fits(card.resource, building, upgrade_level):
			total += card.value

	return total


func _get_xp_card_total() -> float:
	var total : float = 0.0

	for card in chosen_cards:
		if card.resource.card_target == EvolveResource.CardTarget.Xp:
			total += card.value

	return total


func _fits(resource : EvolveResource, building : Building, card_level : int) -> bool:
	if resource.card_target != EvolveResource.CardTarget.Buildings:
		return false

	if building is Wall:
		return resource.fits_walls

	return UpgradeRules.fits_tower(resource, building.skill, building.evolve_tree.evolve_element, card_level)


func _get_upgradable_buildings() -> Array[Building]:
	return level.all_buildings.filter(_is_upgradable)


func _is_upgradable(building : Building) -> bool:
	return is_instance_valid(building) and building.evolve_tree != null


func _emit_xp_changed() -> void:
	GameSignals.upgrade_xp_changed.emit(xp, xp_needed, upgrade_level)
