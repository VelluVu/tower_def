class_name ShieldAura
extends Node2D

## The shieldbearer's tower shield: enemies within `radius` tiles of it (itself too) take `reduction` less from
## bolts (Bolter, Spotter, Harpooner). Several shields do not stack: the strongest one counts. Kill the bearer, or
## use other towers.

const COLOR : Color = Color(0.75, 0.8, 0.86, 0.35)
const COVERED_SKILLS : int = Utils.SkillType.Projectile | Utils.SkillType.Sniper | Utils.SkillType.Harpoon

## In tiles.
@export var radius : float = 1.5
@export_range(0.0, 0.75) var reduction : float = 0.4

@onready var enemy : Enemy = get_parent()


func _ready() -> void:
	add_to_group(GroupNames.SHIELD_AURAS)
	z_index = -1
	queue_redraw()


## The share of a tower's hit that gets through the shields covering this enemy.
static func get_factor(target : Enemy, damage_data : DamageData) -> float:
	var source : Node = damage_data.source
	if source is Trap or source is not Building or source.skill == null or (source.skill.skill_type & COVERED_SKILLS) == 0:
		return 1.0
	var best : float = 0.0
	for node in target.get_tree().get_nodes_in_group(GroupNames.SHIELD_AURAS):
		var aura : ShieldAura = node as ShieldAura
		if aura != null and aura.covers(target):
			best = maxf(best, aura.reduction)
	return 1.0 - best


func covers(target : Enemy) -> bool:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.is_burrowed:
		return false
	return target.global_position.distance_to(enemy.global_position) <= radius * Utils.TILE_SIZE


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius * Utils.TILE_SIZE, 0.0, TAU, 32, COLOR, 1.0)
