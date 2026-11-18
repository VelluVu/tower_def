class_name TowerHitEffects
extends RefCounted

## What a tower's direct hit does besides its damage, from the tower's own stats (tier steps, talents):
## a splash on the enemies around the target and a chance to freeze it. Effect ticks, reactions and
## splashes themselves never set these off.

## The share of the hit each enemy in the splash takes.
const SPLASH_SHARE : float = 0.5
## How far a split shard flies from the target.
const SPLIT_RANGE_TILES : float = 1.5
## The share of the tower's hit a poison spread passes on.
const POISON_SPREAD_SHARE : float = 0.5


static func apply(target : Enemy, damage_data : DamageData, raw_damage : float) -> void:
	if not damage_data.source is Building or damage_data.is_overtime or damage_data.is_reaction or damage_data.is_splash:
		return
	if raw_damage <= 0.0:
		return

	var tower : Building = damage_data.source
	var spread : int = roundi(tower.stats.get_stat_value(Utils.StatType.PoisonSpread))
	if spread > 0 and target.is_dead:
		_spread_poison(target, tower, spread)
	_freeze(target, tower)
	var knockback : int = roundi(tower.stats.get_stat_value(Utils.StatType.Knockback))
	if knockback > 0:
		target.knock_back(knockback)
	var patch_seconds : float = tower.stats.get_stat_value(Utils.StatType.PatchDuration)
	if patch_seconds > 0.0 and tower.level != null:
		GroundPatch.make(target.global_position, tower, damage_data.damage_type, raw_damage, tower.stats.get_stat_value(Utils.StatType.PatchShare), patch_seconds)
	var shards : int = roundi(tower.stats.get_stat_value(Utils.StatType.SplitCount))
	if shards > 0:
		_split(target, tower, damage_data, raw_damage * tower.stats.get_stat_value(Utils.StatType.SplitShare), shards)
	var radius : float = tower.stats.get_stat_value(Utils.StatType.SplashRadius)
	if radius > 0.0:
		_splash(target, tower, damage_data, raw_damage, radius * Utils.TILE_SIZE)


static func _freeze(target : Enemy, tower : Building) -> void:
	var chance : float = tower.stats.get_stat_value(Utils.StatType.FreezeChance)
	if chance > 0.0 and randf() < chance:
		target.freeze_for(tower.stats.get_stat_value(Utils.StatType.FreezeDuration))


#up to count living, reachable enemies within SPLIT_RANGE_TILES of the target, nearest first
static func _nearest_others(target : Enemy, count : int) -> Array:
	var reach : float = SPLIT_RANGE_TILES * Utils.TILE_SIZE
	var near : Array = target.level.existing_enemies.filter(func(enemy : Enemy) -> bool:
		return enemy != target and is_instance_valid(enemy) and not enemy.is_dead and not enemy.is_deactivated and not enemy.is_burrowed \
			and enemy.global_position.distance_to(target.global_position) <= reach)
	near.sort_custom(func(a : Enemy, b : Enemy) -> bool:
		return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
	return near.slice(0, count)


#the dead enemy's poison jumps on: its nearest neighbours get a half-strength copy of the tower's own hit, which
#brings the tower's poison stacks with it (a Poison tower's hit carries them)
static func _spread_poison(target : Enemy, tower : Building, count : int) -> void:
	if target.level == null or tower.skill == null:
		return
	if target.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison).is_empty():
		return
	for enemy in _nearest_others(target, count):
		var infection : DamageData = tower.skill.damage_data
		infection.damage *= POISON_SPREAD_SHARE
		infection.is_splash = true
		enemy.take_damage(infection)
		infection.queue_free()


#each shard flies to one of the nearest other enemies
static func _split(target : Enemy, tower : Building, damage_data : DamageData, shard_damage : float, shards : int) -> void:
	if target.level == null or shard_damage <= 0.0:
		return
	for enemy in _nearest_others(target, shards):
		var shard : DamageData = DamageData.new()
		shard.damage_type = damage_data.damage_type
		shard.damage = shard_damage
		shard.is_splash = true
		shard.source = tower
		enemy.take_damage(shard)
		shard.free()


static func _splash(target : Enemy, tower : Building, damage_data : DamageData, raw_damage : float, reach : float) -> void:
	if target.level == null:
		return

	for enemy in target.level.existing_enemies.duplicate():
		if enemy == target or not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.is_burrowed:
			continue
		if enemy.global_position.distance_to(target.global_position) > reach:
			continue
		var splash : DamageData = DamageData.new()
		splash.damage_type = damage_data.damage_type
		splash.damage = raw_damage * SPLASH_SHARE
		splash.is_splash = true
		splash.source = tower
		enemy.take_damage(splash)
		splash.free()
