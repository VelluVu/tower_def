class_name Enemy
extends RigidBody2D

@onready var attack_timer : Timer = $AttackTimer
@onready var nav_agent : NavigationAgent2D = $NavigationAgent2D
@onready var end_point : Marker2D = $"../EndPoint"
@export var speed : float = 3.0
@export var damage : int = 1
var next_waypoint : Vector2
var closest_building : Building
var is_attacking : bool = false


func _ready() -> void:
	nav_agent.target_position = end_point.global_position
	attack_timer.timeout.connect(attack)
	GameSignals.navigation_rebaked.connect(_on_navigation_rebaked)


func _on_navigation_rebaked() -> void:
	attack_timer.stop()
	nav_agent.target_position = end_point.global_position
	await get_tree().create_timer(3.0).timeout
	is_attacking = false


func _integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	if NavigationServer2D.map_get_iteration_id(nav_agent.get_navigation_map()) == 0:
		return
	
	if nav_agent.is_navigation_finished() or not nav_agent.is_target_reachable():
		move_towards_next_waypoint()
		if global_position.distance_to(nav_agent.get_current_navigation_path()[-1]) < 8.0:
			if not is_attacking:
				start_attacking_closest_wall()
		return
	
	move_towards_next_waypoint()


func move_towards_next_waypoint() -> void:
	next_waypoint = nav_agent.get_next_path_position()
	var direction : Vector2 = global_position.direction_to(next_waypoint)
	var velocity : Vector2 = direction * speed
	look_at(global_position + direction)
	linear_velocity = velocity


func start_attacking_closest_wall() -> void:
	linear_velocity = Vector2.ZERO
	is_attacking = true
	get_closest_building()
	attack_timer.start()


func get_closest_building() -> void:
	var all_buildings = get_tree().get_nodes_in_group(GroupNames.buildings)
	var shortest_distance : float = 99999
	var current_distance : float = 0
	
	for building in all_buildings:
		current_distance = global_position.distance_to(building.global_position)
		if current_distance < shortest_distance:
			shortest_distance = current_distance
			closest_building = building


func attack() -> void:
	if closest_building == null:
		attack_timer.stop()
		return
		
	print("attack")
	closest_building.take_damage(damage)
