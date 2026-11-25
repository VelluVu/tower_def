class_name ShellGuard
extends Node

## The snapping turtle pulls into its shell after a big hit (one taking `trigger_share` of its max health or more):
## for `shell_seconds` it takes only `damage_share` of every hit and crawls at half speed (SHELL). Many small hits
## (Beamer, Breather, effects) beat it; a Spotter's or a Mortar's big blow mostly bounces off the second one.

const SHELL_TINT : Color = Color(0.8, 0.85, 0.7)
const SHELL_SPEED : float = 0.5

@export_range(0.01, 1.0) var trigger_share : float = 0.08
@export var shell_seconds : float = 2.0
@export_range(0.0, 1.0) var damage_share : float = 0.3
@export var cooldown : float = 4.0

@onready var enemy : Enemy = get_parent()

var shell_timer : CustomTimer = null
var cooldown_timer : CustomTimer = null
var slow : ModifierData = null

var is_shelled : bool :
	get:
		return shell_timer != null and not shell_timer.is_stopped()


func _ready() -> void:
	shell_timer = CustomTimer.new()
	shell_timer.one_shot = true
	add_child(shell_timer)
	shell_timer.unscaled_base_value = shell_seconds
	shell_timer.timeout.connect(_open)
	cooldown_timer = CustomTimer.new()
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.unscaled_base_value = cooldown
	GameSignals.enemy_hit.connect(_on_enemy_hit)


func _on_enemy_hit(hit_enemy : Enemy, damage_data : DamageData) -> void:
	if hit_enemy != enemy or is_shelled or not cooldown_timer.is_stopped() or enemy.is_dead or damage_data.is_overtime:
		return
	var max_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
	if max_health <= 0.0 or damage_data.damage < max_health * trigger_share:
		return
	enemy.damage_taken_factor = damage_share
	enemy.walk_animation = GlobalAnimationNames.SHELL_ANIMATION
	enemy.animation_control.self_modulate = SHELL_TINT
	slow = Elite.multiply(Utils.StatType.Speed, SHELL_SPEED)
	enemy.modifier_manager.add_modifier(slow)
	shell_timer.start()


func _open() -> void:
	if not is_instance_valid(enemy):
		return
	enemy.damage_taken_factor = 1.0
	enemy.walk_animation = GlobalAnimationNames.WALK_ANIMATION
	enemy.animation_control.self_modulate = Color.WHITE
	if slow != null:
		enemy.modifier_manager.remove_modifier(slow)
		slow = null
	cooldown_timer.start()
