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

var is_pathing_around_obstacle : bool = false
var is_colliding_building : bool = false
var is_attack_finished : bool = false
var collision_body : Node = null
var current_waypoint_index : int = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 1.0
var velocity : Vector2 = Vector2.ZERO
var last_position : Vector2
var next_waypoint : Vector2 = Vector2.ZERO
var end_point : Marker2D = null
var closest_building : Building = null
var level : Level = null
var point_path : PackedVector2Array
var movement_history : Array[Vector2]
var max_history_size : int = 10

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


func take_damage(incoming_damage : int) -> void:
	stats_manager.stats.health -= incoming_damage
	if stats_manager.stats.health <= 0:
		GameSignals.enemy_destroyed.emit(self)


func iterate_next_waypoint() -> void:
	current_waypoint_index += 1
	
	if current_waypoint_index >= point_path.size():
		return
	
	update_movement_history()
	next_waypoint = point_path[current_waypoint_index]


func update_movement_history() -> void:
	var last_position_in_grid : Vector2 = level.snap_position_to_grid(global_position)
	if not movement_history.has(last_position_in_grid):
		movement_history.push_front(last_position_in_grid)
	else:
		var pos : Vector2 = movement_history.pop_at(movement_history.find(last_position_in_grid))
		movement_history.push_front(pos)
		
	if movement_history.size() >= max_history_size:
		movement_history.pop_back()


func _ready() -> void:
	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	GameSignals.astar_grid_updated.connect(_on_astar_grid_updated)
	GameSignals.building_is_removed.connect(_on_building_removed)
	if not is_in_group(GroupNames.SELECTABLE):
		add_to_group(GroupNames.SELECTABLE)


func _on_body_enter(body : Node) -> void:
	if body.is_in_group(GroupNames.BUILDINGS):
		is_colliding_building = true
		collision_body = body


func _on_body_exit(body : Node):
	if body.is_in_group(GroupNames.BUILDINGS):
		is_colliding_building = false
		collision_body = null


func _on_building_removed() -> void:
	pass
	#is_pathing_around_obstacle = false
	#GameSignals.enemy_path_blocked_change.emit(false)


func _on_animation_finished() -> void:
	if animated_sprite.animation == ATTACK_ANIMATION:
		is_attack_finished = true


func _on_astar_grid_updated() -> void:
	if level == null:
		push_warning(name, GRID_UPDATE_ERROR)
		return
	
	point_path = level.find_path(global_position, end_point.global_position)
	
	if point_path.is_empty():
		next_waypoint = global_position
		return
		
	var direction_to_first_waypoint : Vector2 = global_position.direction_to(point_path[0])
	var dot = velocity.dot(direction_to_first_waypoint)
	current_waypoint_index = 0
	
	if dot < 0:
		current_waypoint_index += 1
	
	if current_waypoint_index >= point_path.size():
		update_movement_history()
		next_waypoint = point_path[0]
		return
	
	update_movement_history()
	next_waypoint = point_path[current_waypoint_index]


func get_closest_cell() -> Vector2i:
	var surrounding_cells : Array[Vector2i] = level.tile_map_main_layer.get_surrounding_cells(level.tile_map_main_layer.local_to_map(global_position))
	var closest_distance : float = 999999999
	var end_point_grid_pos : Vector2i = level.world_position_to_grid(end_point.global_position)
	var closest_cell : Vector2i = Vector2i(-9999,-9999)
	
	for cell in surrounding_cells:
		var world_point : Vector2 = level.grid_position_to_world(cell)
		if point_path.has(world_point):
			continue
			
		if not level.is_cell_walkable(cell):
			continue
			
		var distance_to_end : float = (end_point_grid_pos - cell).length()
		
		if distance_to_end < closest_distance:
			closest_distance = distance_to_end
			closest_cell = cell
	
	return closest_cell


func _get_closest_building() -> void:
	var surrounding_cells : Array[Vector2i] = level.tile_map_main_layer.get_surrounding_cells(level.tile_map_main_layer.local_to_map(global_position))
	var shortest_distance_to_end : float = 999999
	var distance_to_end : float = 0
	
	for cell in surrounding_cells:
		var cell_data : TileData = level.tile_map_main_layer.get_cell_tile_data(cell)
		
		if cell_data == null:
			continue
		
		var is_walkable : bool = cell_data.get_custom_data(level.WALKABLE_CUSTOM_DATA_NAME)
		
		if not is_walkable:
			continue
		
		if level.has_building_in_cell_position(cell):
			var cell_world_position : Vector2 = level.tile_map_main_layer.map_to_local(cell)
			distance_to_end = cell_world_position.distance_to(end_point.global_position)
			if distance_to_end < shortest_distance_to_end:
				shortest_distance_to_end = distance_to_end
				closest_building = level.get_building_from_cell_position(cell)


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
		animated_sprite.play(IDLE_ANIMATION)
		GameSignals.enemy_reached_end_point.emit(self)
		linear_velocity = Vector2.ZERO
		hide()


func Die() -> void:
	if not animated_sprite.animation == DEATH_ANIMATION:
		animated_sprite.play(DEATH_ANIMATION)
	linear_velocity = Vector2.ZERO
	contact_monitor = false
	collider.disabled = true


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
