class_name Enemy
extends RigidBody2D


const STATS_MANAGER_NAME : String = "StatsManager"
const RESOURCE_NAME_END_PART : String = "_stats.tres"
const NUMBERS : String = "0123456789"
const GRID_UPDATE_ERROR : String = ", level is still initializing, unable to react to grid update"
const END_POINT_PATHING_ERROR : String = " can't path to the end point distance: "
const REACHED_END_PATH_MESSAGE : String = " have reached the end of the current path"
const PATH_TO_STAT_RESOURCE : String = "res://scenes/unit/stats/stat_resources/enemy_stats/"

const DEATH_ANIMATION : String = "DEATH"
const WALK_ANIMATION : String = "WALK"
const ATTACK_ANIMATION : String = "ATTACK"
const IDLE_ANIMATION : String = "IDLE"

@onready var attack_timer : Timer = $AttackTimer
@onready var collider : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

@export var icon : Texture2D = null
@export var stats_manager : StatsManager :
	get = _get_stats_manager

var is_colliding_building : bool = false
var is_attack_finished : bool = false
var current_waypoint_index : int = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 1.0
var grid_position : Vector2i
var velocity : Vector2 = Vector2.ZERO
var last_position : Vector2
var next_waypoint : Vector2 = Vector2.ZERO
var collision_body : Node = null
var end_point : Marker2D = null
var closest_building : Building = null
var level : Level = null
var point_path : PackedVector2Array

var stats_resource_name : String :
	get = _get_stats_resource_name

var is_path_end_reached : bool :
	get = _get_is_path_end_reached,
	set = _set_is_path_end_reached

var is_the_end_point_reached : bool :
	get = _get_is_the_end_point_reached,
	set = _set_is_the_end_point_reached

var has_path : bool :
	get:
		return not point_path.is_empty()


func start_enemy(_level : Level, _end_point : Marker2D) -> void:
	level = _level
	end_point = _end_point
	last_position = global_position
	grid_position = level.world_position_to_grid(global_position)


func take_damage(incoming_damage : int) -> void:
	stats_manager.stats.health -= incoming_damage
	if stats_manager.stats.health <= 0:
		GameSignals.enemy_destroyed.emit(self)


func iterate_next_waypoint() -> void:
	if (current_waypoint_index + 1) >= point_path.size():
		next_waypoint = point_path[current_waypoint_index]
		return
	
	current_waypoint_index += 1
	next_waypoint = point_path[current_waypoint_index]


func path_to(from : Vector2, to : Vector2) -> void:
	to = level.snap_position_to_grid(to)
	
	point_path = level.find_path(from, to)
	current_waypoint_index = 0
	
	if point_path.is_empty():
		point_path.append(level.snap_position_to_grid(global_position))
		return
		
	var direction_to_first_waypoint : Vector2 = global_position.direction_to(point_path[0])
	var dot = velocity.dot(direction_to_first_waypoint)
	
	if dot < 0:
		iterate_next_waypoint()
	
	next_waypoint = point_path[current_waypoint_index]


func clear_path() -> void:
	point_path.clear()
	current_waypoint_index = 0


func deactivate() -> void:
	linear_velocity = Vector2.ZERO
	contact_monitor = false
	collider.disabled = true


func die() -> void:
	if not animated_sprite.animation == DEATH_ANIMATION:
		animated_sprite.play(DEATH_ANIMATION)
	deactivate()


func get_closest_building() -> void:
	var surrounding_cells : Array[Vector2i] = level.tiles.ground_layer.get_surrounding_cells(level.tiles.ground_layer.local_to_map(global_position))
	var shortest_distance_to_end : float = 999999
	var distance_to_end : float = 0
	
	for cell in surrounding_cells:
		
		var is_walkable : bool = level.is_cell_walkable(cell)
		
		if not is_walkable:
			continue
		
		if level.has_building_in_cell_position(cell):
			var cell_world_position : Vector2 = level.tiles.ground_layer.map_to_local(cell)
			distance_to_end = cell_world_position.distance_to(end_point.global_position)
			
			if distance_to_end < shortest_distance_to_end:
				shortest_distance_to_end = distance_to_end
				closest_building = level.get_building_from_cell_position(cell)


func is_path_blocked(path : PackedVector2Array) -> bool:
	if path.is_empty():
		return true
	var end_point_position : Vector2 = level.snap_position_to_grid(end_point.global_position)
	var is_last_path_position_end : bool = path[-1] == end_point_position
	return not is_last_path_position_end


func _ready() -> void:
	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	GameSignals.astar_grid_updated.connect(_on_astar_grid_updated)
	
	if not is_in_group(GroupNames.SELECTABLE):
		add_to_group(GroupNames.SELECTABLE)


func _on_body_enter(body : Node) -> void:
	if body.is_in_group(GroupNames.BUILDINGS):
		is_colliding_building = true
		collision_body = body
		closest_building = collision_body


func _on_body_exit(body : Node):
	if body.is_in_group(GroupNames.BUILDINGS):
		is_colliding_building = false
		collision_body = null
		closest_building = null


func _on_animation_finished() -> void:
	if animated_sprite.animation == ATTACK_ANIMATION:
		is_attack_finished = true


func _on_astar_grid_updated() -> void:
	if level == null:
		push_warning(name, GRID_UPDATE_ERROR)
		return

	path_to(global_position, end_point.global_position)


func _get_is_path_end_reached() -> bool:
	return is_path_end_reached


func _set_is_path_end_reached(value : bool) -> void:
	if value == is_path_end_reached:
		return
	is_path_end_reached = value
	if is_path_end_reached:
		print(name, REACHED_END_PATH_MESSAGE)


func _get_is_the_end_point_reached() -> bool:
	return is_the_end_point_reached


func _set_is_the_end_point_reached(value : bool) -> void:
	if value == is_the_end_point_reached:
		return
			
	is_the_end_point_reached = value
	if not is_the_end_point_reached:
		var distance_to_end = global_position.distance_to(end_point.global_position)
		push_warning(name, END_POINT_PATHING_ERROR, distance_to_end)
	else:
		print(name, " enemy has reached the end point")
		GameSignals.enemy_reached_end_point.emit(self)
		deactivate()
		hide()


func _get_stats_manager() -> StatsManager:
	if has_node(STATS_MANAGER_NAME):
		return $StatsManager
	stats_manager = StatsManager.new()
	stats_manager.base_stats = ResourceLoader.load(PATH_TO_STAT_RESOURCE + stats_resource_name)
	stats_manager.name = STATS_MANAGER_NAME
	add_child(stats_manager)
	return stats_manager


func _get_stats_resource_name() -> String:
	return name.rstrip(NUMBERS).to_lower() + RESOURCE_NAME_END_PART
