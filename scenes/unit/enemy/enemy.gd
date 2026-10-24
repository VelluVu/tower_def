class_name Enemy
extends RigidBody2D


const GRID_UPDATE_ERROR : String = ", level is still initializing, unable to react to grid update"
const END_POINT_PATHING_ERROR : String = " can't path to the end point distance: "
const MODULATE_ALPHA_PROPERTY : String = "modulate:a"
const CORPSE_FADE_TIME : float = 1.0
const NO_FREE_POSITION_WARNING : String = " unable to find free position, destroying building in the way."
#a short stop after every turn, so twisting mazes cost time
const TURN_PAUSE_TIME : float = 0.1
#directions closer than this (cosine) count as straight on: about 60 degrees
const TURN_DOT_LIMIT : float = 0.5

@onready var collider : CollisionShape2D = $CollisionShape2D
@onready var animation_control : AnimationControl = $AnimatedSprite2D
@onready var hit_box : Area2D = $Hitbox
@onready var gore_emitter : GoreEmitter = $GoreEmitter
@onready var selectable : SelectableUnit = $SelectableUnit
@onready var pop_up_spot : Node2D = $PopUpSpot

@onready var modifier_manager : ModifierManager = $ModifierManager :
	get:
		if modifier_manager == null:
			modifier_manager = $ModifierManager
		return modifier_manager 

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
var current_waypoint_index : int = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 2.0
var current_time_scale : float = 1.0
var velocity : Vector2 = Vector2.ZERO
var last_position : Vector2 = Vector2.ZERO
var next_waypoint : Vector2 = Vector2.ZERO
var lane_offset : Vector2 = Vector2.ZERO
var collision_body : Node = null
var end_point : Marker2D = null
var point_path : PackedVector2Array
#LevelGrid.get_move_speed_factor of the cell the enemy last stood in
var cell_speed_factor : float = 1.0
var cell_speed_factor_cell : Vector2i = Vector2i.MAX
var turn_pause_timer : CustomTimer = null

var level : Level = null :
	get:
		if level == null:
			level = Utils.game_control.scene_manager.current_level
		return level

var grid_position : Vector2i :
	get:
		return level.grid.world_position_to_grid(global_position)

var body_center : Vector2 :
	get:
		return hit_box.global_position

var is_dead : bool :
	get:
		return stats.get_stat_value(Utils.StatType.Health) <= 0.0

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
		next_waypoint = point_path[current_waypoint_index] + lane_offset
		return

	current_waypoint_index += 1
	next_waypoint = point_path[current_waypoint_index] + lane_offset
	_pause_if_turning()


func _pause_if_turning() -> void:
	if turn_pause_timer == null or velocity.is_zero_approx() or not turn_pause_timer.is_stopped():
		return

	if velocity.normalized().dot(global_position.direction_to(next_waypoint)) < TURN_DOT_LIMIT:
		turn_pause_timer.start()


func is_waypoint_reached() -> bool:
	return global_position.distance_to(next_waypoint) < minimum_distance_to_next_waypoint


func is_last_waypoint() -> bool:
	return (current_waypoint_index + 1) >= point_path.size()


func is_end_point_in_reach() -> bool:
	return global_position.distance_to(end_point.global_position) < minimum_distance_to_end


func move_towards_next_waypoint() -> void:
	animation_control.play_animation(GlobalAnimationNames.WALK_ANIMATION)

	#velocity keeps the old direction, so the turn is not counted twice
	if not turn_pause_timer.is_stopped():
		linear_velocity = Vector2.ZERO
		return

	var move_direction : Vector2 = global_position.direction_to(next_waypoint)
	var speed : float = stats.get_stat_value(Utils.StatType.Speed) * get_spacing_speed_factor(move_direction) * _get_cell_speed_factor()
	velocity = speed * move_direction * current_time_scale
	linear_velocity = velocity
	last_position = global_position
	animation_control.flip_h = linear_velocity.x <= 0


#slow ground and the maze; looked up again only in a new cell or after the buildings change
func _get_cell_speed_factor() -> float:
	if grid_position != cell_speed_factor_cell:
		cell_speed_factor_cell = grid_position
		cell_speed_factor = level.grid.get_move_speed_factor(cell_speed_factor_cell)

	return cell_speed_factor


func path_to(from : Vector2, to : Vector2) -> void:
	#to = level.grid.snap_position_to_grid(to)
	
	point_path = level.grid.find_path(from, to)
	current_waypoint_index = 0
	
	if point_path.is_empty():
		point_path.append(level.grid.snap_position_to_grid(global_position))
		return
		
	var direction_to_first_waypoint : Vector2 = global_position.direction_to(point_path[0])
	var dot = velocity.dot(direction_to_first_waypoint)
	
	if dot < 0:
		iterate_next_waypoint()
		return

	next_waypoint = point_path[current_waypoint_index] + lane_offset


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
	_free_after_death()


#the corpse stays until the death animation and the gore (which leaves the blood splats) have finished
func _free_after_death() -> void:
	if animation_control.is_playing():
		await animation_control.animation_finished

	while gore_emitter.is_emitting():
		await get_tree().process_frame

	var fade : Tween = create_tween()
	fade.set_speed_scale(current_time_scale)
	fade.tween_property(self, MODULATE_ALPHA_PROPERTY, 0.0, CORPSE_FADE_TIME)
	await fade.finished
	queue_free()


func get_building_in_next_waypoint() -> Building:
	var building : Building = level.grid.get_building_from_world_position(level.grid.snap_position_to_grid(next_waypoint))
	if building is Trap:
		return null
	return building


func get_first_nearby_free_position() -> Vector2:
	#find free position, a walkable position without tower or wall in it
	var cells : Array[Vector2i] = level.grid.get_walkable_surrounding_cells(grid_position)
	
	if not cells.is_empty():
		return level.grid.grid_position_to_world(cells.pick_random())
	
	var building_in_cell : Building = level.grid.get_building_from_cell_position(grid_position)

	if building_in_cell != null:
		building_in_cell.destroy_building()
		push_warning(name, NO_FREE_POSITION_WARNING)

	return global_position


func get_spacing_speed_factor(move_direction : Vector2) -> float:
	var neighbour_positions : Array[Vector2] = []
	for enemy in level.existing_enemies:
		if enemy != self and not enemy.is_deactivated:
			neighbour_positions.append(enemy.global_position)
	return EnemySpacing.get_speed_factor(global_position, move_direction, neighbour_positions)


func get_remaining_path_waypoint_count() -> int:
	return range(current_waypoint_index, point_path.size()).size()


#the building in this enemy's cell first, then one in a neighbour cell; traps are walked over, never attacked
func get_closest_building() -> Building:
	var building_in_cell : Building = level.grid.get_building_from_cell_position(grid_position)

	if building_in_cell != null and building_in_cell is not Trap:
		return building_in_cell

	for building in level.grid.get_neighbour_buildings_from_world_position(global_position):
		if building is not Trap:
			return building

	return null


func _ready() -> void:
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE
	
	if not is_in_group(GroupNames.ENEMIES):
		add_to_group(GroupNames.ENEMIES)
	
	var new_name : String = name + str(level.all_enemies.size())
	name = new_name
	last_position = global_position
	_roll_lane_offset()
	turn_pause_timer = CustomTimer.new()
	turn_pause_timer.one_shot = true
	add_child(turn_pause_timer)
	turn_pause_timer.unscaled_base_value = TURN_PAUSE_TIME
	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)
	GameSignals.astar_grid_updated.connect(_on_astar_grid_updated)
	GameSignals.enemy_spawned.emit(self)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)
	overtime_effect_handler.handle_start_overtime_effects(stats.get_stat_value(Utils.StatType.MaxHealth))


func _roll_lane_offset() -> void:
	var body_radius : float = Utils.TILE_SIZE * 0.5
	if collider.shape is CircleShape2D:
		body_radius = collider.shape.radius
	var max_offset : float = EnemySpacing.get_max_lane_offset(body_radius, minimum_distance_to_next_waypoint)
	lane_offset = EnemySpacing.roll_lane_offset(max_offset, randf(), randf())


func _on_body_enter(body : Node) -> void:
	if body.is_in_group(GroupNames.BUILDINGS):
		if body is Trap:
			return
		collision_body = body


func _on_body_exit(body : Node) -> void:
	if body.is_in_group(GroupNames.BUILDINGS):
		collision_body = null


func _on_astar_grid_updated() -> void:
	if is_dead or is_deactivated:
		return
		
	if level == null:
		push_warning(name, GRID_UPDATE_ERROR)
		return

	#a building placed or removed next to the enemy changes its speed
	cell_speed_factor_cell = Vector2i.MAX
	path_to(global_position, end_point.global_position)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale


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
		GameSignals.enemy_reached_end_point.emit(self)
		deactivate()
		hide()
		queue_free()
