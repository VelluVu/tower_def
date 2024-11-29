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
@onready var gore_emitter : GoreEmitter = $GoreEmitter
@onready var selectable : SelectableUnit = $SelectableUnit
@onready var pop_up_spot : Node2D = $PopUpSpot

@onready var overtime_effect_handler : OvertimeEffectHandler = $OvertimeEffectHandler :
	get:
		if overtime_effect_handler == null:
			overtime_effect_handler = $OvertimeEffectHandler
		return overtime_effect_handler

@onready var stats : Stats = $Stats :
	get:
		if stats == null:
			stats = $Stats
		return stats

@export var icon : Texture2D = null

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

var is_colliding_building : bool = false :
	get:
		return collision_body != null

var is_deactivated : bool = false
var time_is_altered : bool = false
var current_waypoint_index : int = 0
var time : float = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 2.0
var current_time_scale : float = 1.0
var grid_position : Vector2i = Vector2i.ZERO
var velocity : Vector2 = Vector2.ZERO
var last_position : Vector2 = Vector2.ZERO
var previous_waypoint : Vector2 = Vector2.ZERO
var next_waypoint : Vector2 = Vector2.ZERO
var collision_body : Node = null
var end_point : Marker2D = null
var closest_building : Building = null
var point_path : PackedVector2Array
var target : Node = null

var level : Level = null :
	get:
		if level == null:
			level = Utils.game_control.scene_manager.current_level
		return level

var body_center : Vector2 :
	get:
		return hit_box.global_position

var is_dead : bool :
	get:
		return stats.get_stat_value(Utils.StatType.Health) <= 0.0

var is_path_end_reached : bool :
	get = _get_is_path_end_reached,
	set = _set_is_path_end_reached

var is_the_end_point_reached : bool :
	get = _get_is_the_end_point_reached,
	set = _set_is_the_end_point_reached

var has_path : bool :
	get:
		return not point_path.is_empty()


signal stats_changed() 
signal selected(is_selected : bool)


func take_damage(damage_data : DamageData) -> void:
	#print(name, " takes damage: ", damage_data.damage)
	if is_dead:
		return
	
	var health : Stat = stats.get_stat(Utils.StatType.Health)
	var maxHealth : Stat = stats.get_stat(Utils.StatType.MaxHealth)
	health.value -= damage_data.damage
	
	if health.value > maxHealth.value and damage_data.is_healing and not damage_data.is_shielding:
		health.value = maxHealth.value
		
	GameSignals.damage_taken.emit(pop_up_spot.global_position, damage_data)
	overtime_effect_handler.handle_overtime_effects(damage_data.overtime_effect_datas, damage_data.damage)
	
	if damage_data.damage > 0.0:
		if damage_data.source != null:
			damage_data.source.dealt_damage(self, damage_data)
		gore_emitter.emit_gore(damage_data)
		animation_control.play_hit_animation()


func dealt_damage(_target : Node2D, _damage_data : DamageData) -> void:
	#print(name, " dealt ", _damage_data.damage ," damage to ", _target.name)
	pass


func iterate_next_waypoint() -> void:
	if (current_waypoint_index + 1) >= point_path.size():
		next_waypoint = point_path[current_waypoint_index]
		
		if previous_waypoint == next_waypoint:
			previous_waypoint = level.world_position_to_grid(global_position)
		return
	
	previous_waypoint = point_path[current_waypoint_index]
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
		return
	
	previous_waypoint = level.world_position_to_grid(global_position)
	next_waypoint = point_path[current_waypoint_index]


func clear_path() -> void:
	point_path.clear()
	current_waypoint_index = 0


func deactivate() -> void:
	overtime_effect_handler.clear_overtime_effects()
	linear_velocity = Vector2.ZERO
	contact_monitor = false
	collider.disabled = true
	hit_box.monitoring = false
	hit_box.monitorable = false
	is_deactivated = true


func reactivate() -> void:
	stats.get_stat(Utils.StatType.Health).value = stats.get_stat_value(Utils.StatType.MaxHealth)
	contact_monitor = true
	collider.disabled = false
	hit_box.monitoring = true
	hit_box.monitorable = true
	is_deactivated = false
	overtime_effect_handler.handle_start_overtime_effects(stats.get_stat_value(Utils.StatType.MaxHealth))


func die() -> void:
	if is_deactivated:
		return
		
	animation_control.play_animation(GlobalAnimationNames.DEATH_ANIMATION)
	GameSignals.enemy_destroyed.emit(self)
	deactivate()


func get_building_in_next_waypoint() -> Building:
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


func get_closest_building() -> Building:
	var closest = level.get_building_from_world_position(global_position)
	
	if closest != null:
		return closest
	
	#save found buildings to variable?
	var neightbour_buildings : Array[Building] = level.get_neighbour_buildings_from_world_position(global_position)
	
	if not neightbour_buildings.is_empty():
		closest = neightbour_buildings[0]
	
	return closest


func _ready() -> void:
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE
	
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
	overtime_effect_handler.handle_start_overtime_effects(stats.get_stat_value(Utils.StatType.MaxHealth))


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
	if is_dead or is_deactivated:
		return
		
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
