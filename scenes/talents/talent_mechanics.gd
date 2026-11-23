class_name TalentMechanics
extends Node

## The talent capstones and signature nodes that are mechanics, not stats (2026-11-16): strikes on every Nth attack
## of a tower (Supernova, Meteor, Blizzard, Pinning Shot, Toxic Bloom, Hydra Bolts), bursts of enemies dying burning
## or frozen (Funeral Pyre, Ice Shards) and the elder dragon in each castle (Keep Awakens). Created by LevelTalents
## when a learned node has one of these effects.

## Hydra Bolts and the other splits: how far a bolt looks for its enemy, and its share of the hit.
const SPLIT_REACH_TILES : float = 1.5
const SPLIT_SHARE : float = 0.5
## Stacks strikes hit this lightly: only the stacks they bring matter.
const STACKS_HIT_SHARE : float = 0.25
## The castle dragon hits bosses this much softer (a share of 4500 health is a lot).
const BOSS_BREATH_FACTOR : float = 0.25

#[effect, value]
var strikes : Array[Array] = []
var death_bursts : Array[Array] = []
var dragon_value : float = 0.0
var dragon_reach : float = 0.0
#tower -> effect -> attacks counted
var attack_counts : Dictionary[Building, Dictionary] = {}
#castle positions whose first leak of this wave was forgiven
var forgiven_castles : Array[Vector2] = []
var dragon_timer : CustomTimer = null

var level : Level :
	get:
		return get_parent().level


## Takes the mechanic effects of the learned nodes; false when there are none (the node is then not needed).
func setup(learned : Array[Dictionary]) -> bool:
	for entry in learned:
		var effect : TalentEffect = entry.effect
		var value : float = effect.value_per_rank * entry.rank
		match effect.kind:
			TalentEffect.Kind.Strike:
				strikes.append([effect, value])
			TalentEffect.Kind.DeathBurst:
				death_bursts.append([effect, value])
			TalentEffect.Kind.CastleDragon:
				dragon_value = maxf(dragon_value, value)
				dragon_reach = maxf(dragon_reach, effect.radius_tiles * Utils.TILE_SIZE)
				if dragon_timer == null:
					dragon_timer = CustomTimer.new()
					dragon_timer.unscaled_base_value = effect.interval
	return not strikes.is_empty() or not death_bursts.is_empty() or dragon_value > 0.0


func _ready() -> void:
	if not strikes.is_empty():
		GameSignals.tower_attacked.connect(_on_tower_attacked)
		GameSignals.sell_building.connect(_forget)
		GameSignals.building_destroyed.connect(_forget)
	if not death_bursts.is_empty():
		GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	if dragon_timer != null:
		add_child(dragon_timer)
		dragon_timer.timeout.connect(_breathe)
		dragon_timer.start()
		#per wave started, not cleared: an early start never clears the wave it overtook
		GameSignals.wave_started.connect(func(_wave : int) -> void: forgiven_castles.clear())


## Keep Awakens: the first enemy to reach each castle every wave costs no life.
func forgives_leak(enemy : Enemy) -> bool:
	if dragon_timer == null or enemy.end_point == null:
		return false
	var castle : Vector2 = enemy.end_point.global_position
	if castle in forgiven_castles:
		return false
	forgiven_castles.append(castle)
	return true


func _forget(building : Building) -> void:
	attack_counts.erase(building)


func _on_tower_attacked(skill : Skill) -> void:
	var tower : Building = skill.actor as Building
	if tower == null or not tower.is_placed:
		return
	for pair in strikes:
		var effect : TalentEffect = pair[0]
		if not _fits(effect, tower):
			continue
		var counts : Dictionary = attack_counts.get_or_add(tower, {})
		counts[effect] = counts.get(effect, 0) + 1
		if counts[effect] < effect.every:
			continue
		counts[effect] = 0
		_strike(effect, pair[1], tower, skill)


#a strike's tower must match the node: its kind, and its element unless the node is for any element
func _fits(effect : TalentEffect, tower : Building) -> bool:
	if effect.buildings & TalentEffect.get_building_flag(tower) == 0:
		return false
	return effect.elements == 0 or (tower.evolve_tree != null and tower.evolve_tree.evolve_element & effect.elements != 0)


func _strike(effect : TalentEffect, value : float, tower : Building, skill : Skill) -> void:
	var target : Enemy = skill.target as Enemy
	var centre : Vector2 = tower.global_position
	var reach : float = 0.0
	if effect.at_tower:
		reach = tower.stats.get_stat_value(Utils.StatType.AttackRange) * Utils.TILE_SIZE * effect.range_factor
	else:
		if target == null or not is_instance_valid(target) or target.is_dead:
			return
		centre = target.global_position
		reach = effect.radius_tiles * Utils.TILE_SIZE
	var hit : Array[Enemy] = _enemies_near(centre, reach) if reach > 0.0 else ([target] as Array[Enemy])
	match effect.strike:
		TalentEffect.StrikeKind.Blast:
			for enemy in hit:
				_hit_with_tower(enemy, skill, value)
		TalentEffect.StrikeKind.Freeze:
			for enemy in hit:
				enemy.freeze_for(value)
		TalentEffect.StrikeKind.Stacks:
			for enemy in hit:
				for i in roundi(value):
					_hit_with_tower(enemy, skill, STACKS_HIT_SHARE)
		TalentEffect.StrikeKind.Split:
			if target == null:
				return
			var near : Array[Enemy] = _enemies_near(target.global_position, SPLIT_REACH_TILES * Utils.TILE_SIZE)
			near.erase(target)
			near.sort_custom(func(a : Enemy, b : Enemy) -> bool:
				return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
			for enemy in near.slice(0, roundi(value)):
				_hit_with_tower(enemy, skill, SPLIT_SHARE)


#a copy of the tower's own hit (its element, burn or poison stacks, crit roll), scaled; marked as a splash so it
#never sets off the hit effects or another strike
func _hit_with_tower(enemy : Enemy, skill : Skill, share : float) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	var data : DamageData = skill.damage_data
	data.damage *= share
	data.is_splash = true
	enemy.take_damage(data)
	data.queue_free()


func _enemies_near(centre : Vector2, reach : float) -> Array[Enemy]:
	var near : Array[Enemy] = []
	for enemy in level.existing_enemies:
		if is_instance_valid(enemy) and not enemy.is_dead and not enemy.is_deactivated and not enemy.is_burrowed \
				and enemy.global_position.distance_to(centre) <= reach:
			near.append(enemy)
	return near


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if not enemy.gives_reward:
		return
	for pair in death_bursts:
		var effect : TalentEffect = pair[0]
		if not TalentEffect.enemy_in(enemy, effect.condition):
			continue
		var damage : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth) * pair[1]
		for other in _enemies_near(enemy.global_position, effect.radius_tiles * Utils.TILE_SIZE):
			if other == enemy:
				continue
			#a boss's thousands of health would wipe out its whole escort: its burst takes each one's own share instead
			var burst : float = other.stats.get_stat_value(Utils.StatType.MaxHealth) * pair[1] if enemy.is_boss else damage
			_hit_plain(other, burst * (BOSS_BREATH_FACTOR if other.is_boss else 1.0), effect.elements)


func _breathe() -> void:
	var castles : Array[Vector2] = [level.end_point.global_position]
	for spawner in get_tree().get_nodes_in_group(GroupNames.SPAWNER):
		if spawner.end_point != null and not spawner.end_point.global_position in castles:
			castles.append(spawner.end_point.global_position)
	for castle in castles:
		for enemy in _enemies_near(castle, dragon_reach):
			var damage : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth) * dragon_value
			_hit_plain(enemy, damage * (BOSS_BREATH_FACTOR if enemy.is_boss else 1.0), Utils.DamageType.Fire)


#damage with no tower behind it (bursts, the dragon): no hit effects, no strikes
func _hit_plain(enemy : Enemy, damage : float, damage_type : int) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead or damage <= 0.0:
		return
	var data : DamageData = DamageData.new()
	data.damage_type = (damage_type if damage_type != 0 else Utils.DamageType.Physical) as Utils.DamageType
	data.damage = damage
	data.is_splash = true
	enemy.take_damage(data)
	data.free()
