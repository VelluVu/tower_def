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
var path_is_blocked : bool = false
var current_waypoint_index : int = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 1.0
var velocity : Vector2 = Vector2.ZERO
var last_position : Vector2
var next_waypoint : Vector2 = Vector2.ZERO
var collision_body : Node = null
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
	if (current_waypoint_index + 1) >= point_path.size():
		next_waypoint = point_path[current_waypoint_index]
		return
	
	update_movement_history()
	current_waypoint_index += 1
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
	
	update_movement_history()
	next_waypoint = point_path[current_waypoint_index]
	path_is_blocked = is_path_blocked(point_path)


func clear_path() -> void:
	point_path.clear()
	current_waypoint_index = 0


class ValuedCell:
	var walkable : bool = true
	var value : float = 1.0
	var distance_to_end : float = 999999999
	var grid_position : Vector2i = Vector2i(-9999,-9999)
	var world_position : Vector2 = Vector2(-9999,-9999)


func sort_cell_value_by_distance_to_end(cell_value_a : ValuedCell, cell_value_b : ValuedCell) -> bool:
	return cell_value_a.distance_to_end <= cell_value_b.distance_to_end


func sort_cell_value_by_highest_value(cell_value_a : ValuedCell, cell_value_b : ValuedCell) -> bool:
	return cell_value_a.value > cell_value_b.value


func get_optimal_cell_to_move() -> Vector2i:
	var surrounding_cells : Array[Vector2i] = level.tile_map_main_layer.get_surrounding_cells(level.tile_map_main_layer.local_to_map(global_position))
	var valued_cells : Array[ValuedCell]
	
	for cell in surrounding_cells:
		var valued_cell = ValuedCell.new()
		valued_cells.append(valued_cell)
		valued_cell.grid_position = cell
		valued_cell.world_position = level.grid_position_to_world(cell)
		valued_cell.distance_to_end = (end_point.global_position - valued_cell.world_position).length()
	
	valued_cells.sort_custom(sort_cell_value_by_distance_to_end)
	var index : int = -1
	
	for cell in valued_cells:
		index += 1
		
		if not level.is_cell_walkable(cell.grid_position):
			cell.value = 0.0
			cell.walkable = false
			continue
		
		if index == 0:
			cell.value = 1.0
		if index == 1:
			cell.value = 0.9
		if index == 2:
			cell.value = 0.8
		if index == 3:
			cell.value = 0.7
		
		if movement_history.has(cell.world_position):
			cell.value = 0.0
		
		
		var direction_to_cell : Vector2 = global_position.direction_to(cell.world_position)
		var direction_to_end : Vector2 = global_position.direction_to(end_point.global_position)
		var is_moving_towards_end : bool = direction_to_cell.dot(direction_to_end) > 0.0
		
		if is_moving_towards_end:
			cell.value += 0.1
		
		var move_direction = movement_history[0].direction_to(global_position)
		var is_moving_forward : bool = move_direction.dot(direction_to_cell) > 0.0
		
		if is_moving_forward:
			cell.value += 0.1
	
	valued_cells.sort_custom(sort_cell_value_by_highest_value)
	
	if valued_cells[0].value == 0.0:
		return Utils.BAD_CELL
	
	return valued_cells[0].grid_position


func get_closest_cell() -> Vector2i:
	var surrounding_cells : Array[Vector2i] = level.tile_map_main_layer.get_surrounding_cells(level.tile_map_main_layer.local_to_map(global_position))
	var closest_distance : float = 999999999
	var end_point_grid_pos : Vector2i = level.world_position_to_grid(end_point.global_position)
	var closest_cell : Vector2i = Vector2i(-9999,-9999)
	
	for cell in surrounding_cells:
		if not level.is_cell_walkable(cell):
			continue
			
		var distance_to_end : float = (end_point_grid_pos - cell).length()
		
		if distance_to_end < closest_distance:
			closest_distance = distance_to_end
			closest_cell = cell
	
	return closest_cell


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
		closest_building = collision_body


func _on_body_exit(body : Node):
	if body.is_in_group(GroupNames.BUILDINGS):
		is_colliding_building = false
		collision_body = null
		closest_building = null


func _on_building_removed() -> void:
	pass


func _on_animation_finished() -> void:
	if animated_sprite.animation == ATTACK_ANIMATION:
		is_attack_finished = true


func _on_astar_grid_updated() -> void:
	if level == null:
		push_warning(name, GRID_UPDATE_ERROR)
		return
	
	#WHAT IF PATH IS BLOCKED IN AND IT WAS NOT BLOCKED PREVIOUSLY
	print(name, " current path blocked: ", path_is_blocked)
	if not path_is_blocked:
		path_to(global_position, end_point.global_position)
	else:
		var test_path = level.find_path(global_position, level.snap_position_to_grid(end_point.global_position))
		if not is_path_blocked(test_path):
			path_to(global_position, end_point.global_position)


func is_path_blocked(path : PackedVector2Array) -> bool:
	if path.is_empty():
		return true
	var end_point_position : Vector2 = level.snap_position_to_grid(end_point.global_position)
	var is_last_path_position_end : bool = path[-1] == end_point_position
	return not is_last_path_position_end


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
