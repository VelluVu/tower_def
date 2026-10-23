class_name LevelUpgrades
extends Node

## Level-wide upgrades: one XP bar fed by every kill, and the chosen cards applied to every tower.
## Lives under the Level, so everything resets when the level is unloaded.

const CARD_COUNT : int = 4
const XP_PER_MAX_HEALTH : float = 2.0
const NO_CARDS_WARNING : String = " no upgrade cards fit the placed towers, skipping level "

var xp : float = 0.0
var upgrade_level : int = 1
var pending_level_ups : int = 0
var is_finished : bool = false
var offered_cards : Array[UpgradeCard]
var chosen_cards : Array[UpgradeCard]
#building -> {UpgradeCard: ModifierData}, kept so a card can be taken off when the element changes
var applied_cards : Dictionary[Building, Dictionary] = {}

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
	add_xp(enemy.stats.get_stat_value(Utils.StatType.MaxHealth) * XP_PER_MAX_HEALTH)


func _on_level_finished(_level : Level = null) -> void:
	is_finished = true


func _on_building_placed(building : Building) -> void:
	if not _is_upgradable(building):
		return

	#BuildingTypeUpgrades has already set the type's element, later element changes refit the cards
	building.evolve_tree.element_changed.connect(_on_element_changed.bind(building))

	for card in chosen_cards:
		_apply_stat_card(building, card)


func _on_building_removed(building : Building) -> void:
	applied_cards.erase(building)


#a card that fit the old element comes off, a chosen card that fits the new one goes on
func _on_element_changed(_element : Utils.Element, building : Building) -> void:
	var cards : Dictionary = applied_cards.get(building, {})

	for card in chosen_cards:
		var fits : bool = UpgradeRules.fits_tower(card.resource, building.skill, building.evolve_tree.evolve_element, upgrade_level)

		if fits and not cards.has(card):
			_apply_stat_card(building, card)
		elif not fits and cards.has(card):
			building.modifier_manager.remove_modifier(cards[card])
			cards.erase(card)

	building.stats_changed.emit()


func _on_upgrade_card_selected(index : int) -> void:
	if index < 0 or index >= offered_cards.size():
		return

	var card : UpgradeCard = offered_cards[index]
	offered_cards.clear()
	upgrade_level += 1
	pending_level_ups -= 1

	chosen_cards.append(card)

	for building in level.all_buildings:
		if _is_upgradable(building):
			_apply_stat_card(building, card)

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
		for building in _get_upgradable_buildings():
			if UpgradeRules.fits_tower(resource, building.skill, building.evolve_tree.evolve_element, new_level):
				pool.append(resource)
				break

	pool.shuffle()
	var cards : Array[UpgradeCard] = []

	for resource in pool.slice(0, CARD_COUNT):
		cards.append(UpgradeCard.from_resource(resource, UpgradeRules.roll_value(resource, randf())))

	return cards


func _apply_stat_card(building : Building, card : UpgradeCard) -> void:
	if not UpgradeRules.fits_tower(card.resource, building.skill, building.evolve_tree.evolve_element, upgrade_level):
		return

	var modifier_data : ModifierData = card.get_modifier_data()
	building.modifier_manager.add_modifier(modifier_data)

	if not applied_cards.has(building):
		applied_cards[building] = {}

	applied_cards[building][card] = modifier_data
	building.stats_changed.emit()


func _get_upgradable_buildings() -> Array[Building]:
	return level.all_buildings.filter(_is_upgradable)


func _is_upgradable(building : Building) -> bool:
	return is_instance_valid(building) and building is not Wall and building.evolve_tree != null


func _emit_xp_changed() -> void:
	GameSignals.upgrade_xp_changed.emit(xp, xp_needed, upgrade_level)
