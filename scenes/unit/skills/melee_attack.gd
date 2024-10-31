class_name MeleeAttack
extends Skill


@onready var attack_area : Area2D = $AttackArea
@onready var collision_shape : CollisionShape2D = $AttackArea/CollisionShape2D

@export var damage_type : Utils.DamageType = Utils.DamageType.Normal


func _ready() -> void:
	super()


func use(_target) -> void:
	if _target == null:
		return
		
	super(_target)
	var direction_to_target = (_target.global_position - actor.global_position).normalized()
	attack_area.position = Vector2.ZERO + direction_to_target * (Utils.TILE_SIZE * 0.5)
	actor.animation_control.flip_h = direction_to_target.x < 0.0


func activate() -> void:
	super()
	activate_collision_detection(true)


func _on_attack_area_body_entered(body: Node2D) -> void:
	activate_collision_detection(false)
	body.take_damage(damage, damage_type)


func _on_active_end() -> void:
	activate_collision_detection(false)
	super()


func _interrupted_active() -> void:
	activate_collision_detection(false)
	super()


func activate_collision_detection(state : bool) -> void:
	collision_shape.set_deferred("disabled", not state)
	attack_area.set_deferred("monitorable", state)
	attack_area.set_deferred("monitoring", state)
