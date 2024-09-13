class_name Enemy
extends RigidBody2D


@onready var attack_timer : Timer = $AttackTimer
@export var speed : float = 3.0
@export var damage : int = 1
@export var health : int = 2
@export var gold_loot : int = 1
var end_point : Marker2D = null
var is_nav_enabled : bool = false
var current_waypoint_index : int = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 1.0
var next_waypoint : Vector2 = Vector2.ZERO
var closest_building : Building = null
var level : Level = null
var point_path : PackedVector2Array

var is_attacking : bool :
	get:
		return is_attacking
	set(value):
		if is_attacking == value:
			return
		is_attacking = value
		if is_attacking:
			start_attacking_closest_building()
		else:
			attack_timer.stop()

var has_path : bool :
	get:
		return not point_path.is_empty()

var is_path_end_reached : bool :
	get:
		return is_path_end_reached
	set(value):
		if value == is_path_end_reached:
			return
		is_path_end_reached = value
		if is_path_end_reached:
			print(name, " have reached the end of the current path")
		
var is_the_end_point_reached : bool :
	get:
		return is_the_end_point_reached
	set(value):
		if value == is_the_end_point_reached:
			return
			
		is_the_end_point_reached = value
		if not is_the_end_point_reached:
			var distance_to_end = global_position.distance_to(end_point.global_position)
			print(name, " can't path to the end point distance: ", distance_to_end)
		else:
			GameSignals.enemy_reached_end_point.emit(self)
			linear_velocity = Vector2.ZERO
			hide()


func _ready() -> void:
	GameSignals.astar_grid_updated.connect(_on_astar_grid_updated)
	attack_timer.timeout.connect(attack)


func start_enemy(_level : Level, _end_point : Marker2D) -> void:
	level = _level
	end_point = _end_point
	point_path = level.find_path(global_position, end_point.global_position)
	current_waypoint_index = 0
	is_nav_enabled = true


func _on_astar_grid_updated() -> void:
	if level == null:
		print(name, ", level is still initializing, unable to react to grid update")
		return
		
	point_path = level.find_path(global_position, end_point.global_position)
	
	if point_path.size() > 1:
		is_attacking = false
		
	var direction_to_first_waypoint : Vector2 = global_position.direction_to(point_path[0])
	var dot = linear_velocity.dot(direction_to_first_waypoint)
	current_waypoint_index = 0
	
	if dot < 0:
		current_waypoint_index += 1


func _physics_process(_delta: float) -> void:
	if not is_nav_enabled:
		return
	
	if not has_path:
		return
	
	is_path_end_reached = current_waypoint_index >= point_path.size()
	if is_path_end_reached:
		linear_velocity = Vector2.ZERO
		var distance_to_end = global_position.distance_to(end_point.global_position)
		is_the_end_point_reached = distance_to_end < minimum_distance_to_end
		if not is_attacking and not is_the_end_point_reached:
			is_attacking = true
		return
	
	if is_attacking:
		return
	
	move_towards_next_waypoint()


func move_towards_next_waypoint() -> void:
	var distance_to_next_waypoint : float = global_position.distance_to(next_waypoint)
	
	if distance_to_next_waypoint < minimum_distance_to_next_waypoint:
		current_waypoint_index += 1
		if current_waypoint_index >= point_path.size():
			return
	
	next_waypoint = point_path[current_waypoint_index]
	var direction : Vector2 = global_position.direction_to(next_waypoint)
	var velocity : Vector2 = direction * speed
	look_at(global_position + direction)
	linear_velocity = velocity


func start_attacking_closest_building() -> void:
	get_closest_building()
	attack_timer.start()


func get_closest_building() -> void:
	var surrounding_cells : Array[Vector2i] = level.tile_map.get_surrounding_cells(level.tile_map.local_to_map(global_position))
	var shortest_distance_to_end : float = 999999
	var distance_to_end : float = 0
	
	for cell in surrounding_cells:
		if level.has_building_in_cell_position(cell):
			var cell_world_position : Vector2 = level.tile_map.map_to_local(cell)
			distance_to_end = cell_world_position.distance_to(end_point.global_position)
			if distance_to_end < shortest_distance_to_end:
				shortest_distance_to_end = distance_to_end
				closest_building = level.get_building_from_cell_position(cell)


func attack() -> void:
	if closest_building == null:
		attack_timer.stop()
		return
		
	print("attack")
	closest_building.take_damage(damage)


func take_damage(incoming_damage : int) -> void:
	health -= incoming_damage
	if health <= 0:
		GameSignals.enemy_destroyed.emit(self)
		linear_velocity = Vector2.ZERO
		hide()
