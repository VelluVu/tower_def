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
	#a Shredder's pulse tears the target's armour
	if tower is Shredder and not target.is_dead:
		#its niche (2026-11-26): double stacks on a pinned or slowed enemy, twice as long on elites and bosses
		var is_tough : bool = target.is_boss or target.get_node_or_null(NodePath(Elite.NAME)) != null
		var seconds : float = Shredder.SHRED_SECONDS * (TowerNiches.SHRED_TOUGH_SECONDS_FACTOR if is_tough else 1.0)
		for stack in (TowerNiches.SHRED_PINNED_STACKS if TowerNiches.is_pinned(target) else 1):
			ResistanceShred.give(target, Shredder.SHRED_PER_STACK, Shredder.MAX_STACKS, seconds)
	#a Spotter's mark: the target takes more of this element from every tower for a while
	var mark_share : float = tower.stats.get_stat_value(Utils.StatType.MarkShare)
	if mark_share > 0.0 and not target.is_dead:
		EnemyMarks.mark(target, damage_data.damage_type, mark_share)
	_execute(target, tower)
	#a Harpooner's chain: slowed for a while, a flyer dragged to the ground
	var tether_seconds : float = tower.stats.get_stat_value(Utils.StatType.TetherTime)
	if tether_seconds > 0.0 and not target.is_dead:
		#a fast runner stays leashed longer (the Harpooner's niche, 2026-11-26)
		if TowerNiches.is_fast(target):
			tether_seconds *= TowerNiches.FAST_TETHER_FACTOR
		HarpoonTether.attach(target, tower, tether_seconds, tower.stats.get_stat_value(Utils.StatType.TetherSlow))
		#the harpoon tears: a bleed (the user, 2026-11-26), and the tethered enemy bleeds harder from everything
		HarpoonTether.bleed(target, tower, raw_damage)
	var spread : int = roundi(tower.stats.get_stat_value(Utils.StatType.PoisonSpread))
	if spread > 0 and target.is_dead:
		_spread_poison(target, tower, spread)
	_freeze(target, tower)
	var knockback : int = roundi(tower.stats.get_stat_value(Utils.StatType.Knockback))
	if knockback > 0:
		target.knock_back(knockback)
	var patch_seconds : float = tower.stats.get_stat_value(Utils.StatType.PatchDuration)
	#a Breather leaves one patch in its cone per gust instead (Breath)
	if patch_seconds > 0.0 and tower.level != null and not (tower.skill != null and tower.skill.skill_type == Utils.SkillType.Breath):
		GroundPatch.make(target.global_position, tower, damage_data.damage_type, raw_damage, tower.stats.get_stat_value(Utils.StatType.PatchShare), patch_seconds)
	var shards : int = roundi(tower.stats.get_stat_value(Utils.StatType.SplitCount))
	if shards > 0:
		_split(target, tower, damage_data, raw_damage * tower.stats.get_stat_value(Utils.StatType.SplitShare), shards)
	var radius : float = tower.stats.get_stat_value(Utils.StatType.SplashRadius)
	#a Mortar's and an Egg Bomb's splash radius widens their blast instead (MortarShell, EggBomb)
	if radius > 0.0 and not (tower.skill != null and tower.skill.skill_type in [Utils.SkillType.Artillery, Utils.SkillType.Blast]):
		_splash(target, tower, damage_data, raw_damage, radius * Utils.TILE_SIZE)
	#a Buffer's element rides on the hits of the buildings in its aura
	if target.level != null and target.level.buffer_auras != null and not target.is_dead:
		target.level.buffer_auras.on_direct_hit(target, tower, raw_damage)


#a Spotter's execute: a non-boss enemy left under the share of its max health dies to the hit
static func _execute(target : Enemy, tower : Building) -> void:
	var below : float = tower.stats.get_stat_value(Utils.StatType.ExecuteBelow)
	if below <= 0.0 or target.is_dead or target.is_boss:
		return
	#Torn and marked: the execute reaches higher on a shredded enemy
	var torn : float = Synergies.get_execute_bonus(target)
	var health : float = target.stats.get_stat_value(Utils.StatType.Health)
	if health <= 0.0 or health >= target.stats.get_stat_value(Utils.StatType.MaxHealth) * (below + torn):
		return
	var is_torn_kill : bool = torn > 0.0 and health >= target.stats.get_stat_value(Utils.StatType.MaxHealth) * below
	if is_torn_kill and target.level != null and target.level.synergies != null:
		target.level.synergies.flash(&"torn", tower.global_position, target.global_position)
	var finisher : DamageData = DamageData.new()
	finisher.damage_type = Utils.DamageType.Physical
	#past every resistance and shield: the whole rest of its health, as a splash so no hit effects come again
	finisher.damage = health / maxf(target.get_resistance_factor(finisher), 0.01) / maxf(target.damage_taken_factor, 0.01) + 1.0
	finisher.is_splash = true
	finisher.source = tower
	target.take_damage(finisher)
	finisher.free()


static func _freeze(target : Enemy, tower : Building) -> void:
	var chance : float = tower.stats.get_stat_value(Utils.StatType.FreezeChance)
	if chance > 0.0 and randf() < chance:
		target.freeze_for(tower.stats.get_stat_value(Utils.StatType.FreezeDuration))


#an enemy other than the target that a tower's splash, shard or spread can land on: alive, above ground,
#within reach, and in the air only for a tower that hits flyers (a sandstorm's hidden flyers never)
#enemy untyped: a freed one must reach the is_instance_valid check, a typed parameter rejects it first
static func _can_reach(enemy, target : Enemy, tower : Building, reach : float) -> bool:
	if not is_instance_valid(enemy) or enemy == target or enemy.is_dead or enemy.is_deactivated or enemy.is_burrowed:
		return false
	if enemy.is_flying and (enemy.is_concealed or (tower is Tower and not tower.hits_air)):
		return false
	return enemy.global_position.distance_to(target.global_position) <= reach


#up to count living, reachable enemies within SPLIT_RANGE_TILES of the target, nearest first
static func _nearest_others(target : Enemy, tower : Building, count : int) -> Array:
	var reach : float = SPLIT_RANGE_TILES * Utils.TILE_SIZE
	var near : Array = target.level.existing_enemies.filter(func(enemy) -> bool: return _can_reach(enemy, target, tower, reach))
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
	for enemy in _nearest_others(target, tower, count):
		var infection : DamageData = tower.skill.damage_data
		infection.damage *= POISON_SPREAD_SHARE
		infection.is_splash = true
		enemy.take_damage(infection)
		infection.queue_free()


#each shard flies to one of the nearest other enemies
static func _split(target : Enemy, tower : Building, damage_data : DamageData, shard_damage : float, shards : int) -> void:
	if target.level == null or shard_damage <= 0.0:
		return
	for enemy in _nearest_others(target, tower, shards):
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
		if not _can_reach(enemy, target, tower, reach):
			continue
		var splash : DamageData = DamageData.new()
		splash.damage_type = damage_data.damage_type
		splash.damage = raw_damage * SPLASH_SHARE
		splash.is_splash = true
		splash.source = tower
		enemy.take_damage(splash)
		splash.free()
