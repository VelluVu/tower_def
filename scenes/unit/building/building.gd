class_name Building
extends StaticBody2D


const SKILL_STATS_NODE_NAME : String = "Stats"
const SKILL_DAMAGE_DATA_NODE_NAME : String = "DamageData"

@onready var evolve_level_up_particle_effect : GPUParticles2D = $EvolveLevelUpParticleEffect
@onready var animation_control : AnimationControl = $AnimatedSprite2D
@onready var collision_shape : CollisionShape2D = $CollisionShape2D
@onready var selectable : SelectableUnit = $SelectableUnit
@onready var placement_validator : PlacementValidator = $PlacementValidator
@onready var pop_up_spot : Node2D = $PopUpSpot
@onready var overtime_effect_handler : OvertimeEffectHandler = $OvertimeEffectHandler
@onready var evolve_tree : EvolveTree = $EvolveTree

@onready var modifier_manager : ModifierManager = $ModifierManager :
	get:
		if modifier_manager == null:
			modifier_manager = $ModifierManager
		return modifier_manager 
@onready var stats : Stats = $Stats :
	get:
		if stats == null:
			stats = $Stats
		return stats
@onready var evolve_glow : AnimationControl = $EvolveGlow : 
	get:
		if evolve_glow == null:
			evolve_glow = $EvolveGlow
		return evolve_glow

@export var player_index : int = 0
@export var closest_point_distance_limit : float = 0.9

@export var skill : Skill : 
	get:
		if skill == null:
			for child in get_children():
				if child is Skill:
					skill = child
		return skill

@export var beehave_tree : BeehaveTree :
	get: 
		if beehave_tree == null:
			for child in get_children():
				if child is BeehaveTree:
					beehave_tree = child
		return beehave_tree

@export var icon : Texture2D = null
@export var astar_weight : float = 100.0

var is_dead : bool :
	get:
		return stats.get_stat_value(Utils.StatType.Health) <= 0.0
		
var is_overlapping_area : bool = false
var is_overlapping_body : bool = false
var id : int = 0
var grid_position : Vector2i = Vector2i(0,0)

var level : Level :
	get :
		if level == null:
			level = get_parent().get_parent()
		return level

var is_valid_placement : bool :
	get = _get_is_valid_placement,
	set = _set_is_valid_placement

var is_placing : bool :
	get = _get_is_placing,
	set = _set_is_placing

var is_placed : bool:
	get = _get_is_placed,
	set = _set_is_placed

var radius : float :
	get = _get_radius

var corners : Array[Vector2] : 
	get = _get_corners

signal stats_changed() 
signal selected(is_selected : bool)


func place(value : Vector2) -> void:
	is_placing = false
	global_position = value
	grid_position = level.world_position_to_grid(global_position)
	level.astar_grid.set_point_weight_scale(grid_position, astar_weight)
	is_placed = true
	GameSignals.building_placed.emit(self)


func take_damage(damage_data : DamageData):
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
		animation_control.play_hit_animation()
		if damage_data.source != null:
			damage_data.source.dealt_damage(self, damage_data)
	
	if stats.get_stat_value(Utils.StatType.Health) <= 0.0:
		destroy_building()


func destroy_building() -> void:
	GameSignals.building_destroyed.emit(self)


#kill XP goes to LevelUpgrades through GameSignals.enemy_destroyed
func dealt_damage(_target : Node2D, _damage_data : DamageData) -> void:
	pass


func replace_skill(new_skill_scene : PackedScene) -> void:
	var old_skill : Skill = skill
	var new_skill : Skill = new_skill_scene.instantiate()
	old_skill.stop()
	#the skill scenes leave Stats and DamageData to the building scene, so a new skill without
	#them takes the old ones over, with the cards and upgrades already on the stats
	var has_own_stats : bool = new_skill.has_node(SKILL_STATS_NODE_NAME)
	
	if not has_own_stats:
		_move_child_node(old_skill, new_skill, SKILL_STATS_NODE_NAME)
	
	if not new_skill.has_node(SKILL_DAMAGE_DATA_NODE_NAME):
		_move_child_node(old_skill, new_skill, SKILL_DAMAGE_DATA_NODE_NAME)
	
	new_skill.position = old_skill.position
	#the element skill scenes are shared, the sound belongs to the tower
	if new_skill.activate_sound == null:
		new_skill.activate_sound = old_skill.activate_sound
	skill = new_skill
	add_child(skill)
	
	if has_own_stats:
		_move_skill_modifiers(old_skill.stats, skill.stats)
	
	old_skill.queue_free()
	modifier_manager.calculate_all_modifiers()
	_on_skill_replaced()


#subclasses reconnect what listens to the skill's stats
func _on_skill_replaced() -> void:
	pass


func _move_child_node(from : Node, to : Node, node_name : String) -> void:
	var node : Node = from.get_node_or_null(node_name)
	
	if node == null:
		return
	
	from.remove_child(node)
	to.add_child(node)


#the new skill starts without the cards and upgrades the old one had
func _move_skill_modifiers(from_stats : Stats, to_stats : Stats) -> void:
	for old_stat in from_stats.stats:
		var new_stat : Stat = to_stats.get_stat(old_stat.type)
		
		if new_stat == null:
			continue
		
		new_stat.flat_modifiers.append_array(old_stat.flat_modifiers)
		new_stat.additive_modifiers.append_array(old_stat.additive_modifiers)
		new_stat.multiply_modifiers.append_array(old_stat.multiply_modifiers)
		new_stat.global_flat_modifiers.append_array(old_stat.global_flat_modifiers)
		new_stat.global_additive_modifiers.append_array(old_stat.global_additive_modifiers)
		new_stat.global_multiply_modifiers.append_array(old_stat.global_multiply_modifiers)


func replace_animation_control(new_animation_control_scene : PackedScene) -> void:
	var current_animation = animation_control.animation
	var _position : Vector2 = animation_control.position
	animation_control.queue_free()
	animation_control = new_animation_control_scene.instantiate()
	add_child(animation_control)
	animation_control.position = _position
	animation_control.play_animation(current_animation)


func remove() -> void:
	collision_shape.disabled = true
	queue_free()


func flip(target_direction : Vector2) -> void:
	animation_control.flip(target_direction)
	skill.flip_h = animation_control.flip_h


func _ready():
	evolve_glow.visible = false
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE
	if not is_in_group(GroupNames.BUILDINGS):
		add_to_group(GroupNames.BUILDINGS)
	
	name = name + str(id) + str(player_index)
	_add_main_stats_to_skill_stats()

#no need to add main stats to skill stats !
func _add_main_stats_to_skill_stats() -> void:
	for stat in stats.stats:
		var skill_stat : Stat = skill.stats.get_stat(stat.type)
		if skill_stat != null:
			skill_stat.value += stat.value


func _on_time_scale_change(_time_scale : float) -> void:
	pass


func _enable_tower() -> void:
	collision_shape.disabled = false
	placement_validator.activate(false)
	GameSignals.forced_selection.emit(self)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)
	overtime_effect_handler.handle_start_overtime_effects(stats.get_stat_value(Utils.StatType.MaxHealth))


func _get_is_placed() -> bool:
	return is_placed


func _set_is_placed(value : bool):
	#print(name, " is placed: ", value)
	if is_placed == value:
		return
		
	is_placed = value
	
	if is_placed:
		_enable_tower()


func _get_is_valid_placement() -> bool:
	return is_valid_placement


func _set_is_valid_placement(value : bool) -> void:
	is_valid_placement = value
	
	if is_valid_placement:
		show()
	else:
		hide()
		
	BuildingPlacementDrawer.draw_building(collision_shape.shape.get_rect(), global_position, is_valid_placement, is_placing)


func _get_is_placing() -> bool:
	return is_placing


func _set_is_placing(value : bool) -> void:
	if is_placing == value:
		return
		
	is_placing = value
	
	if not is_placing:
		BuildingPlacementDrawer.draw_building(collision_shape.shape.get_rect(), global_position, is_valid_placement, is_placing)
	else:
		if collision_shape == null:
			collision_shape = $CollisionShape2D
			
		collision_shape.disabled = true
		GameSignals.building_is_placing.emit(self)


func _get_corners() -> Array[Vector2]:
	var rect : Rect2 = collision_shape.shape.get_rect()
	var half_extends : Vector2 = rect.size * 0.5
	var vector_array : Array[Vector2] = []
	vector_array.append(position - half_extends)
	vector_array.append(Vector2(position.x + half_extends.x, position.y - half_extends.y))
	vector_array.append(Vector2(position.x - half_extends.x, position.y + half_extends.y))
	vector_array.append(position + half_extends)
	return vector_array


func _get_radius() -> float:
	if stats == null:
		return 0.0
	
	if skill == null:
		return stats.get_range_in_tiles()
	
	return skill.stats.get_range_in_tiles()
