class_name LevelTalents
extends Node

## Applies the learned talents during a level: start gold once, and one modifier per learned
## building stat effect on every building it fits. Lives under the Level, like LevelUpgrades.

const TALENT_BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")

#building -> the talent modifiers on it
var applied_modifiers : Dictionary[Building, Array] = {}

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level


func _ready() -> void:
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_removed)
	GameSignals.building_destroyed.connect(_on_building_removed)
	level.player_stats.gold += get_start_gold()


## Every learned effect of the trees with its rank.
static func get_learned_effects() -> Array[Dictionary]:
	var learned : Array[Dictionary] = []

	for tree in TALENT_BOOK.trees:
		var ranks : Dictionary = PlayerProgress.get_talent_ranks(tree.id)

		for node_id in ranks:
			var node : TalentNode = tree.get_node_by_id(node_id)

			if node == null:
				continue

			for effect in node.effects:
				learned.append({"effect": effect, "rank": ranks[node_id]})

	return learned


static func get_start_gold() -> float:
	var gold : float = 0.0

	for entry in get_learned_effects():
		var effect : TalentEffect = entry.effect
		if effect.kind == TalentEffect.Kind.StartGold:
			gold += effect.value_per_rank * entry.rank

	return gold


func _on_building_placed(building : Building) -> void:
	if building.evolve_tree != null and not building.evolve_tree.element_changed.is_connected(_on_element_changed):
		building.evolve_tree.element_changed.connect(_on_element_changed.bind(building))

	_refresh(building)


func _on_building_removed(building : Building) -> void:
	applied_modifiers.erase(building)


#an element talent comes off when the building leaves the element, and goes on when it takes it
func _on_element_changed(_element : Utils.Element, building : Building) -> void:
	_refresh(building)


func _refresh(building : Building) -> void:
	if not is_instance_valid(building):
		return

	#Health is not modified with MaxHealth, so keep the damage taken and add the new max on top
	var missing_health : float = building.stats.get_stat_value(Utils.StatType.MaxHealth) - building.stats.get_stat_value(Utils.StatType.Health)

	for modifier in applied_modifiers.get(building, []):
		building.modifier_manager.remove_modifier(modifier)

	var modifiers : Array[ModifierData] = []

	for entry in get_learned_effects():
		var effect : TalentEffect = entry.effect

		if effect.fits(building):
			var modifier : ModifierData = effect.get_modifier_data(entry.rank)
			building.modifier_manager.add_modifier(modifier)
			modifiers.append(modifier)

	applied_modifiers[building] = modifiers

	var health : Stat = building.stats.get_stat(Utils.StatType.Health)
	if health != null:
		health.value = building.stats.get_stat_value(Utils.StatType.MaxHealth) - missing_health

	building.stats_changed.emit()
