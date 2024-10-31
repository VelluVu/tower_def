class_name Enemy
extends RigidBody2D


const STATS_MANAGER_NAME : String = "StatsManager"
const RESOURCE_NAME_END_PART : String = "_stats.tres"
const NUMBERS : String = "0123456789"
const GRID_UPDATE_ERROR : String = ", level is still initializing, unable to react to grid update"
const END_POINT_PATHING_ERROR : String = " can't path to the end point distance: "
const REACHED_END_PATH_MESSAGE : String = " have reached the end of the current path"
const PATH_TO_STAT_RESOURCE : String = "res://scenes/unit/stats/stat_resources/enemy_stats/"

@onready var collider : CollisionShape2D = $CollisionShape2D
@onready var animation_control : AnimationControl = $AnimatedSprite2D
@onready var hit_box : Area2D = $Hitbox
@onready var hit_animation_player : AnimationPlayer = $HitAnimationPlayer
@onready var gore_emitter : GoreEmitter = $GoreEmitter
@onready var selectable : SelectableUnit = $SelectableUnit
@onready var pop_up_spot : Node2D = $PopUpSpot

@export var skill : Skill :
	get:
		if skill == null:
			for child in get_children():
				if child is Skill:
					skill = child
		return skill


var beehave_tree : BeehaveTree :
	get:
		if beehave_tree == null:
			for child in get_children():
				if child is BeehaveTree:
					beehave_tree = child
		return beehave_tree

@export var icon : Texture2D = null

var stats_manager : StatsManager :
	get = _get_stats_manager

var is_colliding_building : bool = false :
	get:
		return collision_body != null
		
var time_is_altered : bool = false
var current_waypoint_index : int = 0
var time : float = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 2.0
var current_time_scale : float = 1.0
var grid_position : Vector2i = Vector2i.ZERO
var velocity : Vector2 = Vector2.ZERO
var last_position : Vector2 = Vector2.ZERO
var next_waypoint : Vector2 = Vector2.ZERO
var collision_body : Node = null
var end_point : Marker2D = null
var closest_building : Building = null
var level : Level = null
var point_path : PackedVector2Array
var target : Node = null


var body_center : Vector2 :
	get:
		return hit_box.global_position

var is_dead : bool :
	get:
		return stats_manager.stats.health <= 0

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


func inject_objects(_level : Level, _end_point : Marker2D) -> void:
	level = _level
	end_point = _end_point


func take_damage(incoming_damage : int, damage_type : Utils.DamageType) -> void:
	print(name, " takes damage: ", incoming_damage)
	stats_manager.stats.health -= incoming_damage
	GameSignals.damage_taken.emit(pop_up_spot.global_position, incoming_damage, damage_type)
	gore_emitter.emit_gore(incoming_damage)
	
	if hit_animation_player.is_playing():
		hit_animation_player.stop()
		
	hit_animation_player.play("hit")


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
	hit_box.monitoring = false
	hit_box.monitorable = false


func reactivate() -> void:
	stats_manager.stats.health = stats_manager.stats.max_health
	contact_monitor = true
	collider.disabled = false
	hit_box.monitoring = true
	hit_box.monitorable = true


func die() -> void:
	animation_control.play_animation(GlobalAnimationNames.DEATH_ANIMATION)
	GameSignals.enemy_destroyed.emit(self)
	deactivate()


func get_building_in_next_waypoint() -> Building:
	closest_building = null
	
	if level.has_building_in_world_position(next_waypoint):
		closest_building = level.get_building_from_world_position(next_waypoint)
	
	return closest_building


func get_remaining_path_waypoint_count() -> int:
	return range(current_waypoint_index, point_path.size()).size()


func is_path_blocked(path : PackedVector2Array) -> bool:
	if path.is_empty():
		return true
	var end_point_position : Vector2 = level.snap_position_to_grid(end_point.global_position)
	var is_last_path_position_end : bool = path[-1] == end_point_position
	return not is_last_path_position_end


func _ready() -> void:
	if not is_in_group(GroupNames.ENEMIES):
		add_to_group(GroupNames.ENEMIES)
		
	time = 0
	var new_name : String = name + str(level.all_enemies.size())
	name = new_name
	last_position = global_position
	grid_position = level.world_position_to_grid(global_position)
	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)
	GameSignals.astar_grid_updated.connect(_on_astar_grid_updated)
	GameSignals.enemy_spawned.emit(self)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)


func _process(delta: float) -> void:
	if time_is_altered:
		delta *= current_time_scale
	time += delta


func _on_body_enter(body : Node) -> void:
	if body.is_in_group(GroupNames.BUILDINGS):
		collision_body = body
		closest_building = collision_body


func _on_body_exit(body : Node):
	if body.is_in_group(GroupNames.BUILDINGS):
		collision_body = null
		closest_building = null


func _on_astar_grid_updated() -> void:
	if level == null:
		push_warning(name, GRID_UPDATE_ERROR)
		return

	path_to(global_position, end_point.global_position)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	time_is_altered = current_time_scale != 1.0


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
		stats_manager = get_node(STATS_MANAGER_NAME)
		return stats_manager
		
	stats_manager = StatsManager.new()
	var base_stats_name : String = PATH_TO_STAT_RESOURCE + stats_resource_name
	stats_manager.base_stats = ResourceLoader.load(base_stats_name)
	stats_manager.name = STATS_MANAGER_NAME
	add_child(stats_manager)
	return stats_manager


func _get_stats_resource_name() -> String:
	return name.rstrip(NUMBERS).to_lower() + RESOURCE_NAME_END_PART
