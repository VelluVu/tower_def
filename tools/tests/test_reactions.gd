extends RefCounted

## Element reactions: shared points, Combustion, Thermal Shock, Frostplague, cooldowns.

const COMBUSTION : ElementReaction = preload("res://scenes/reactions/reactions/combustion.tres")
const THERMAL_SHOCK : ElementReaction = preload("res://scenes/reactions/reactions/thermal_shock.tres")
const FROSTPLAGUE : ElementReaction = preload("res://scenes/reactions/reactions/frostplague.tres")
const TOUGH_HEALTH : float = 1000.0
const HIT : float = 10.0
#past the 2 s of Thermal Shock and Frostplague at the unlock points
const TIMED_SECONDS : float = 2.5


func test_shared_points_and_values(kit : TestKit) -> void:
	kit.check(ElementReaction.shared_points_of(12, 7) == 7, "the lower tree counts")
	kit.check(not COMBUSTION.is_unlocked(4) and COMBUSTION.is_unlocked(5), "unlocks at 5 shared points")
	kit.check_near(COMBUSTION.get_value(5), 1.0, "base at the unlock")
	kit.check_near(COMBUSTION.get_value(10), 1.2, "+4% per point past 5")
	kit.check_near(COMBUSTION.get_value(99), 2.0, "stops growing at 30")
	kit.check(COMBUSTION.get_partner(Utils.DamageType.Poison) == Utils.DamageType.Fire, "works in both orders")
	kit.check(COMBUSTION.get_partner(Utils.DamageType.Frost) == Utils.DamageType.None, "Frost is not in Combustion")


func test_combustion_hits_around_once_per_cooldown(kit : TestKit) -> void:
	await kit.load_level(1)
	var target : Enemy = _tough_enemy(kit)
	var neighbour : Enemy = _tough_enemy(kit)
	await kit.frames()
	_add_stack(target, Utils.DamageType.Poison)

	_hit(target, Utils.DamageType.Fire)
	kit.check(kit.level.reactions.timed_reactions.is_empty(), "locked: no reaction without talent points")
	kit.check_near(_lost(neighbour), 0.0, "locked: the neighbour is not hit")

	kit.level.reactions.shared_points[COMBUSTION] = COMBUSTION.unlock_points
	_hit(target, Utils.DamageType.Fire)
	kit.check_near(_lost(neighbour), HIT, "the burst hits the neighbour for the whole hit")
	kit.check_near(_lost(target), HIT * 3.0, "two hits and the burst on the target")
	kit.check(not target.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison).is_empty(), "the poison stays")

	_hit(target, Utils.DamageType.Fire)
	kit.check_near(_lost(neighbour), HIT, "on cooldown: no second burst")


func test_thermal_shock_slows_past_the_floor_for_a_while(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.level.reactions.shared_points[THERMAL_SHOCK] = THERMAL_SHOCK.unlock_points
	var enemy : Enemy = _tough_enemy(kit)
	await kit.frames()
	var speed : float = enemy.stats.get_stat_value(Utils.StatType.Speed)
	_add_stack(enemy, Utils.DamageType.Fire)

	_hit(enemy, Utils.DamageType.Frost)
	kit.check_near(enemy.stats.get_stat_value(Utils.StatType.Speed), speed * (1.0 + THERMAL_SHOCK.slow), "the shock slows")
	kit.check_near(enemy.modifier_manager.slow_floor, THERMAL_SHOCK.slow_floor, "the floor is lower")
	kit.check_near(enemy.overtime_effect_handler.tick_rate_bonus, THERMAL_SHOCK.tick_rate_bonus, "effects tick faster")

	await kit.run_until(func() -> bool: return false, TIMED_SECONDS)
	kit.check_near(enemy.stats.get_stat_value(Utils.StatType.Speed), speed, "the slow ends")
	kit.check_near(enemy.modifier_manager.slow_floor, ModifierManager.SLOW_FLOOR, "the floor is back")
	kit.check_near(enemy.overtime_effect_handler.tick_rate_bonus, 0.0, "ticks are back to normal")


func test_frostplague_numbs_for_a_while(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.level.reactions.shared_points[FROSTPLAGUE] = FROSTPLAGUE.unlock_points
	var enemy : Enemy = _tough_enemy(kit)
	await kit.frames()
	_add_stack(enemy, Utils.DamageType.Frost)

	_hit(enemy, Utils.DamageType.Poison)
	kit.check(enemy.is_numb, "a Poison hit on a slowed enemy numbs it")
	await kit.run_until(func() -> bool: return false, TIMED_SECONDS)
	kit.check(not enemy.is_numb, "the numbness ends")


func _tough_enemy(kit : TestKit) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy("swbeefling")
	enemy.stats.get_stat(Utils.StatType.MaxHealth).value = TOUGH_HEALTH
	enemy.stats.get_stat(Utils.StatType.Health).value = TOUGH_HEALTH
	return enemy


#a long stack with no damage, so it marks the enemy without changing its health
func _add_stack(enemy : Enemy, damage_type : Utils.DamageType) -> void:
	var data : OvertimeEffectData = OvertimeEffectData.new()
	data.effectType = Utils.OvertimeEffectType.Stack
	data.damage_type = damage_type
	data.tick_damage = 0.0
	data.max_count = 20
	enemy.overtime_effect_handler.add_overtime_effect(data, 0.0)
	data.free()


func _hit(enemy : Enemy, damage_type : Utils.DamageType) -> void:
	var hit : DamageData = DamageData.new()
	hit.damage_type = damage_type
	hit.damage = HIT
	enemy.take_damage(hit)
	hit.free()


func _lost(enemy : Enemy) -> float:
	return TOUGH_HEALTH - enemy.stats.get_stat_value(Utils.StatType.Health)
