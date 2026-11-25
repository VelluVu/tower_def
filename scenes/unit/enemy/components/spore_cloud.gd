class_name SporeCloud
extends Node2D

## A cloud of healing spores left where a spore carrier was killed (DeathCloud): for `duration` seconds every enemy
## inside heals `heal_share` of its max health each second. A Fire hit inside burns it away early.

const TICK_SECONDS : float = 0.5
const COLOR : Color = Color(0.55, 0.85, 0.35, 0.28)
const EDGE_COLOR : Color = Color(0.7, 0.95, 0.45, 0.6)

var radius_pixels : float = 24.0
var duration : float = 4.0
var heal_share : float = 0.06
var level : Level = null
var tick_timer : CustomTimer = null
var life_timer : CustomTimer = null


static func make(at_level : Level, at : Vector2, radius_tiles : float, seconds : float, share : float) -> SporeCloud:
	var cloud : SporeCloud = SporeCloud.new()
	cloud.level = at_level
	cloud.radius_pixels = radius_tiles * Utils.TILE_SIZE
	cloud.duration = seconds
	cloud.heal_share = share
	cloud.position = at_level.to_local(at)
	at_level.add_child(cloud)
	return cloud


func _ready() -> void:
	z_index = 1
	tick_timer = CustomTimer.new()
	add_child(tick_timer)
	tick_timer.unscaled_base_value = TICK_SECONDS
	tick_timer.timeout.connect(_heal)
	tick_timer.start()
	life_timer = CustomTimer.new()
	life_timer.one_shot = true
	add_child(life_timer)
	life_timer.unscaled_base_value = duration
	life_timer.timeout.connect(queue_free)
	life_timer.start()
	GameSignals.enemy_hit.connect(_on_enemy_hit)


func _heal() -> void:
	if level == null or not is_instance_valid(level):
		queue_free()
		return
	for enemy in level.existing_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.is_flying:
			continue
		if enemy.global_position.distance_to(global_position) > radius_pixels:
			continue
		var health : Stat = enemy.stats.get_stat(Utils.StatType.Health)
		var max_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
		health.value = minf(health.value + max_health * heal_share * TICK_SECONDS, max_health)


func _on_enemy_hit(enemy : Enemy, damage_data : DamageData) -> void:
	if damage_data.damage_type == Utils.DamageType.Fire and damage_data.damage > 0.0 \
			and enemy.global_position.distance_to(global_position) <= radius_pixels:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius_pixels, COLOR)
	draw_arc(Vector2.ZERO, radius_pixels, 0.0, TAU, 32, EDGE_COLOR, 1.0)
