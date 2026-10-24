class_name ElementReactions
extends Node

## Runs the element reactions in a level: listens to direct hits on enemies, keeps the cooldowns
## per enemy and ends the timed reactions. Uses its own game clock (scaled by the game speed,
## stopped by pause), so it needs no timer per enemy. Created by the Level.

const REACTIONS : Array[ElementReaction] = [
	preload("res://scenes/reactions/reactions/combustion.tres"),
	preload("res://scenes/reactions/reactions/thermal_shock.tres"),
	preload("res://scenes/reactions/reactions/frostplague.tres"),
]

class TimedReaction:
	var enemy : Enemy = null
	var end_time : float = 0.0
	var finish : Callable


var game_time : float = 0.0
var current_time_scale : float = 1.0
#enemy -> {reaction: game time it can happen again}
var cooldowns : Dictionary[Enemy, Dictionary] = {}
var timed_reactions : Array[TimedReaction] = []
var shared_points : Dictionary[ElementReaction, int] = {}

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level


func _ready() -> void:
	for reaction in REACTIONS:
		shared_points[reaction] = get_shared_points(reaction)

	GameSignals.enemy_hit.connect(_on_enemy_hit)
	GameSignals.enemy_destroyed.connect(_on_enemy_gone)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_gone)
	GameSignals.time_scale_change.connect(_on_time_scale_change)

	if Utils.game_control != null:
		current_time_scale = Utils.game_control.time_scale


func _process(delta : float) -> void:
	game_time += delta * current_time_scale

	for timed in timed_reactions.duplicate():
		if timed.end_time <= game_time:
			_finish(timed)


## The shared points of a reaction from the player's talents.
static func get_shared_points(reaction : ElementReaction) -> int:
	var first_spent : int = TalentRules.get_spent(PlayerProgress.get_talent_ranks(reaction.first_tree))
	var second_spent : int = TalentRules.get_spent(PlayerProgress.get_talent_ranks(reaction.second_tree))
	return ElementReaction.shared_points_of(first_spent, second_spent)


func _on_enemy_hit(enemy : Enemy, hit : DamageData) -> void:
	#only direct hits: ticks and reaction damage set off nothing
	if hit.is_overtime or hit.is_reaction or hit.damage <= 0.0:
		return

	for reaction in REACTIONS:
		var points : int = shared_points.get(reaction, 0)

		if not reaction.is_unlocked(points):
			continue

		var partner : Utils.DamageType = reaction.get_partner(hit.damage_type)

		if partner == Utils.DamageType.None or enemy.overtime_effect_handler.get_active_stacks(partner).is_empty():
			continue

		if _is_on_cooldown(enemy, reaction):
			continue

		_trigger(reaction, enemy, hit, reaction.get_value(points))


func _trigger(reaction : ElementReaction, enemy : Enemy, hit : DamageData, value : float) -> void:
	#a dying enemy still bursts, but gets no timed reaction
	if reaction.kind != ElementReaction.Kind.Combustion and enemy.is_dead:
		return

	if not cooldowns.has(enemy):
		cooldowns[enemy] = {}
	cooldowns[enemy][reaction] = game_time + reaction.cooldown
	GameSignals.element_reaction.emit(enemy.pop_up_spot.global_position, reaction)

	match reaction.kind:
		ElementReaction.Kind.Combustion:
			_combust(reaction, enemy, hit, value)
		ElementReaction.Kind.ThermalShock:
			_thermal_shock(reaction, enemy, value)
		ElementReaction.Kind.Frostplague:
			_frostplague(enemy, value)


func _combust(reaction : ElementReaction, enemy : Enemy, hit : DamageData, value : float) -> void:
	var reach : float = reaction.radius * Utils.TILE_SIZE + Utils.TILE_SIZE * 0.5
	var center : Vector2 = enemy.global_position

	#a copy: the burst can kill enemies, which leave the list
	for other in level.existing_enemies.duplicate():
		if not is_instance_valid(other) or other.is_dead or other.global_position.distance_to(center) > reach:
			continue

		var burst : DamageData = DamageData.new()
		burst.is_reaction = true
		burst.damage_type = Utils.DamageType.Fire
		burst.damage = hit.damage * value
		burst.source = hit.source
		other.take_damage(burst)
		burst.queue_free()


func _thermal_shock(reaction : ElementReaction, enemy : Enemy, duration : float) -> void:
	var shock_slow : ModifierData = ModifierData.new()
	shock_slow.stat_type = Utils.StatType.Speed
	shock_slow.calculate_type = Utils.ModifyType.Multiply
	shock_slow.value = reaction.slow
	#the floor first, so the slow is worked out with it
	enemy.modifier_manager.slow_floor = reaction.slow_floor
	enemy.modifier_manager.add_modifier(shock_slow)
	enemy.overtime_effect_handler.tick_rate_bonus = reaction.tick_rate_bonus

	_add_timed(enemy, duration, func() -> void:
		enemy.modifier_manager.slow_floor = ModifierManager.SLOW_FLOOR
		enemy.modifier_manager.remove_modifier(shock_slow)
		enemy.overtime_effect_handler.tick_rate_bonus = 0.0)


func _frostplague(enemy : Enemy, duration : float) -> void:
	enemy.is_numb = true
	_add_timed(enemy, duration, func() -> void: enemy.is_numb = false)


func _add_timed(enemy : Enemy, duration : float, finish : Callable) -> void:
	var timed : TimedReaction = TimedReaction.new()
	timed.enemy = enemy
	timed.end_time = game_time + duration
	timed.finish = finish
	timed_reactions.append(timed)


func _finish(timed : TimedReaction) -> void:
	timed_reactions.erase(timed)

	if is_instance_valid(timed.enemy):
		timed.finish.call()


func _is_on_cooldown(enemy : Enemy, reaction : ElementReaction) -> bool:
	return cooldowns.has(enemy) and cooldowns[enemy].get(reaction, 0.0) > game_time


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale


#a pooled enemy comes back fresh: end its reactions now and forget its cooldowns
func _on_enemy_gone(enemy : Enemy) -> void:
	for timed in timed_reactions.duplicate():
		if timed.enemy == enemy:
			_finish(timed)

	cooldowns.erase(enemy)
