class_name MeleeAttack
extends Skill


@onready var attack_area : Area2D = $AttackArea
@onready var collision_shape : CollisionShape2D = $AttackArea/CollisionShape2D
#@onready var attack_hit_box_player : AnimationPlayer = $AttackHitBoxPlayer

@export_flags_2d_physics var attack_mask

@export var attack_distance : float = 0.0
@export var attack_size : float = 14.0
#var can_attack : bool = false


func _ready() -> void:
	super()
	attack_area.collision_mask = attack_mask
	var shape = collision_shape.shape
	
	if shape is RectangleShape2D:
		shape.size.x = attack_size
		shape.size.y = attack_size
	if shape is CircleShape2D:
		shape.radius = attack_size


func use(_target) -> void:
	if _target == null:
		return
	
	super(_target)
	var direction_to_target = (_target.global_position - actor.global_position).normalized()
	attack_area.position = Vector2.ZERO + direction_to_target * attack_distance
	actor.animation_control.flip_h = direction_to_target.x < 0.0


func activate() -> void:
	super()
	activate_collision_detection(true)


func _on_attack_area_body_entered(body: Node2D) -> void:
	activate_collision_detection(false)
	
	if body is Trap:
		return
	
	body.take_damage(damage_data)


func _on_active_end() -> void:
	activate_collision_detection(false)
	super()


func _interrupted_active() -> void:
	activate_collision_detection(false)
	super()


#deferred turning on and off has too much latency in game
func activate_collision_detection(is_activate : bool) -> void:
	#if is_activate:
		#attack_hit_box_player.play(GlobalAnimationNames.ATTACK_ANIMATION)
	#collision_shape.disabled = not state
	#attack_area.process_mode = Node.PROCESS_MODE_DISABLED if not state else Node.PROCESS_MODE_INHERIT
	collision_shape.set_deferred("disabled", not is_activate)
	attack_area.set_deferred("monitorable", is_activate)
	attack_area.set_deferred("monitoring", is_activate)
