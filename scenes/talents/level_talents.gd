class_name LevelTalents
extends Node

## Applies the learned talents during a level: start gold once, and one modifier per learned
## building stat effect on every building it fits. Lives under the Level, like LevelUpgrades.

const TALENT_BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")
const MECHANICS_NAME : String = "TalentMechanics"

#building -> the talent modifiers on it
var applied_modifiers : Dictionary[Building, Array] = {}

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level


#the level-wide kinds, summed once per level: kind -> value (ranks counted in)
var totals : Dictionary[TalentEffect.Kind, float] = {}
#Vulnerability, Weakness and WallArmor need their filters: [effect, value]
var conditional : Array[Array] = []
var mending_timer : CustomTimer = null
#the element towers without one lean to: the element tree with the most ranks learned
var leaning_element : int = Utils.Element.None
#the strikes, death bursts and castle dragon; null without such a talent
var mechanics : TalentMechanics = null
#the last wave WaveGold paid for
var last_paid_wave : int = 0


func _ready() -> void:
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_removed)
	GameSignals.sell_building.connect(_refund_upgrades)
	GameSignals.building_destroyed.connect(_on_building_destroyed)
	level.player_stats.gold += get_start_gold()
	leaning_element = get_leaning_element()
	var new_mechanics : TalentMechanics = TalentMechanics.new()
	if new_mechanics.setup(get_learned_effects()):
		mechanics = new_mechanics
		mechanics.name = MECHANICS_NAME
		add_child(mechanics)
	else:
		new_mechanics.free()
	_sum_level_effects()
	level.grid.talent_maze_slow = get_total(TalentEffect.Kind.MazeSlow)
	GameSignals.wave_cleared.connect(_on_wave_cleared)
	if get_total(TalentEffect.Kind.Mending) > 0.0:
		mending_timer = CustomTimer.new()
		add_child(mending_timer)
		mending_timer.unscaled_base_value = 1.0
		mending_timer.timeout.connect(_mend)
		mending_timer.start()


func _sum_level_effects() -> void:
	for entry in get_learned_effects():
		var effect : TalentEffect = entry.effect
		var value : float = effect.value_per_rank * entry.rank
		match effect.kind:
			TalentEffect.Kind.Vulnerability, TalentEffect.Kind.Weakness, TalentEffect.Kind.WallArmor, TalentEffect.Kind.BufferStrength, TalentEffect.Kind.BufferBudget:
				conditional.append([effect, value])
			TalentEffect.Kind.BuildingStat, TalentEffect.Kind.StartGold, TalentEffect.Kind.UnlockTier, 					TalentEffect.Kind.Strike, TalentEffect.Kind.DeathBurst, TalentEffect.Kind.CastleDragon:
				pass
			_:
				totals[effect.kind] = totals.get(effect.kind, 0.0) + value


func get_total(kind : TalentEffect.Kind) -> float:
	return totals.get(kind, 0.0)


## A Buffer talent's total for this Buffer (BufferStrength, BufferBudget): effects of no element count for every
## Buffer, an element's only once the Buffer has taken it.
func get_buffer_bonus(kind : TalentEffect.Kind, buffer : Buffer) -> float:
	var bonus : float = 0.0
	for pair in conditional:
		var effect : TalentEffect = pair[0]
		if effect.kind != kind:
			continue
		if effect.elements != 0 and (buffer.element == Utils.Element.None or effect.elements & buffer.element == 0):
			continue
		bonus += pair[1]
	return bonus


## The extra damage share an enemy takes from this hit (burning, poisoned, frozen, chilled enemies).
func get_vulnerability(enemy : Enemy, damage_data : DamageData) -> float:
	var bonus : float = 0.0
	for pair in conditional:
		var effect : TalentEffect = pair[0]
		if effect.kind != TalentEffect.Kind.Vulnerability:
			continue
		if effect.buildings != 0 and not (damage_data.source is Building and effect.buildings & TalentEffect.get_building_flag(damage_data.source) != 0):
			continue
		if effect.elements != 0 and effect.elements & damage_data.damage_type == 0:
			continue
		if not TalentEffect.enemy_in(enemy, effect.condition):
			continue
		if effect.per_stack:
			bonus += pair[1] * enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison).size()
		else:
			bonus += pair[1]
	return bonus


## The share less damage an enemy deals to buildings (poisoned, burning, chilled attackers).
func get_weakness(enemy : Enemy) -> float:
	var reduction : float = 0.0
	for pair in conditional:
		var effect : TalentEffect = pair[0]
		if effect.kind == TalentEffect.Kind.Weakness and TalentEffect.enemy_in(enemy, effect.condition):
			reduction += pair[1]
	return minf(reduction, 0.75)


## The share less damage a wall takes from this hit.
func get_wall_armor(damage_data : DamageData) -> float:
	var armor : float = 0.0
	for pair in conditional:
		var effect : TalentEffect = pair[0]
		if effect.kind == TalentEffect.Kind.WallArmor and (effect.elements == 0 or effect.elements & damage_data.damage_type != 0):
			armor += pair[1]
	return minf(armor, 0.75)


#early starts clear several waves at once (only the last one is announced): each of them pays
func _on_wave_cleared(wave_number : int) -> void:
	var waves : int = maxi(wave_number - last_paid_wave, 1)
	last_paid_wave = wave_number
	var gold : float = get_total(TalentEffect.Kind.WaveGold)
	if gold > 0.0:
		level.player_stats.add_gold(gold * waves)


#walls mend the full share, towers and traps a quarter of it
func _mend() -> void:
	var share : float = get_total(TalentEffect.Kind.Mending)
	for building in level.all_buildings:
		if not is_instance_valid(building) or building.is_dead or not building.is_placed:
			continue
		var health : Stat = building.stats.get_stat(Utils.StatType.Health)
		var max_health : float = building.stats.get_stat_value(Utils.StatType.MaxHealth)
		if health == null or health.value >= max_health:
			continue
		health.value = minf(health.value + max_health * (share if building is Wall else share * 0.25), max_health)


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


## The ranks learned in one tree (TalentTree.id), all its nodes together.
static func get_tree_ranks(tree_id : StringName) -> int:
	var ranks : int = 0
	for rank in PlayerProgress.get_talent_ranks(tree_id).values():
		ranks += int(rank)
	return ranks


## The tree with this id, null when the book has none.
static func get_talent_tree(tree_id : StringName) -> TalentTree:
	for tree in TALENT_BOOK.trees:
		if tree.id == tree_id:
			return tree
	return null


## The element of the element tree with the most ranks learned (the first in the book on a tie), None without any.
static func get_leaning_element() -> Utils.Element:
	var best : Utils.Element = Utils.Element.None
	var best_ranks : int = 0
	for tree in TALENT_BOOK.trees:
		if tree.element == Utils.Element.None:
			continue
		var ranks : int = 0
		for rank in PlayerProgress.get_talent_ranks(tree.id).values():
			ranks += int(rank)
		if ranks > best_ranks:
			best = tree.element
			best_ranks = ranks
	return best


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


#Salvage: a share of the gold its upgrades cost comes back with the building's own price
func _refund_upgrades(building : Building) -> void:
	var share : float = get_total(TalentEffect.Kind.SellRefund)
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	if upgrades == null:
		return
	var spent : float = upgrades.upgrade_gold.get(building, 0.0)
	upgrades.upgrade_gold.erase(building)
	if share > 0.0 and spent > 0.0:
		level.player_stats.add_gold(floorf(spent * share))
		GameSignals.gold_refunded.emit(building.global_position, floorf(spent * share))


func _on_building_removed(building : Building) -> void:
	applied_modifiers.erase(building)


#a sell erases its upgrade gold in _refund_upgrades (Salvage reads it first); a destroyed tower's stayed as a freed key
func _on_building_destroyed(building : Building) -> void:
	_on_building_removed(building)
	if level.building_type_upgrades != null:
		level.building_type_upgrades.upgrade_gold.erase(building)


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

		if effect.fits(building, leaning_element):
			var modifier : ModifierData = effect.get_modifier_data(entry.rank)
			building.modifier_manager.add_modifier(modifier)
			modifiers.append(modifier)

	applied_modifiers[building] = modifiers

	var health : Stat = building.stats.get_stat(Utils.StatType.Health)
	if health != null:
		health.value = building.stats.get_stat_value(Utils.StatType.MaxHealth) - missing_health

	building.stats_changed.emit()
