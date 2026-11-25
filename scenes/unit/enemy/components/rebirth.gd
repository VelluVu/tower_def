class_name Rebirth
extends Node

## The phoenix and the ember wisp come back once where they fell, at a share of their health and worth no gold,
## unless the killing hit was Frost. A wisp's spark is also stamped out by a Nova's burst or a trap
## (put_out_by_area).

@export_range(0.1, 1.0) var health_share : float = 0.6
@export var put_out_by_area : bool = false

@onready var enemy : Enemy = get_parent()

#the copy that came back: it does not come back again
var is_used : bool = false
var is_put_out : bool = false


func _ready() -> void:
	GameSignals.enemy_hit.connect(_on_enemy_hit)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


## Whether a hit puts it out for good: Frost always, a Nova, a Mortar or a trap when put_out_by_area.
func puts_out(damage_data : DamageData) -> bool:
	if damage_data.damage_type == Utils.DamageType.Frost:
		return true
	if not put_out_by_area:
		return false
	var source : Node = damage_data.source
	if source is Trap:
		return true
	return source is Building and source.skill != null and (source.skill.skill_type & (Utils.SkillType.Area | Utils.SkillType.Artillery | Utils.SkillType.Breath)) != 0


func _on_enemy_hit(hit_enemy : Enemy, damage_data : DamageData) -> void:
	if hit_enemy == enemy and damage_data.damage > 0.0:
		is_put_out = puts_out(damage_data)


func _on_enemy_destroyed(destroyed : Enemy) -> void:
	if destroyed != enemy or is_used or is_put_out or not enemy.is_dead or not enemy.gives_reward:
		return
	if enemy.scene_file_path.is_empty() or enemy.level == null:
		return
	var copy : Enemy = EnemySummon.summon(load(enemy.scene_file_path), enemy, enemy.global_position)
	if copy == null:
		return
	LevelModeData.scale_health(copy, health_share)
	copy.modifier_manager.add_modifier(Elite.multiply(Utils.StatType.Price, 0.0))
	for child in copy.get_children():
		if child is Rebirth:
			child.is_used = true
