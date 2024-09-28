class_name Building
extends StaticBody2D

const PATH_TO_STAT_RESOURCE : String = "res://scenes/unit/stats/stat_resources/building_stats/"

@onready var sprite : Sprite2D = $Sprite2D
@onready var collision_shape : CollisionShape2D = $CollisionShape2D

@export var id : int = 0
@export var player_index : int = 0
@export var closest_point_distance_limit : float = 0.9
@export var icon : Texture2D = null
@export var stats_manager : StatsManager :
	get = _get_stats_manager

var is_overlapping_area : bool = false
var is_overlapping_body : bool = false
var building_index : int = 0

var stats_resource_name : String :
	get = _get_stats_resource_name

var is_valid_placement : bool :
	get = _get_is_valid_placement,
	set = _set_is_valid_placement

var is_placing : bool :
	get = _get_is_placing,
	set = _set_is_placing

var is_placed : bool:
	get = _get_is_placed,
	set = _set_is_placed

var corners : Array[Vector2] : 
	get = _get_corners


func take_damage(damage : int):
	stats_manager.stats.health -= damage
	if stats_manager.stats.health <= 0:
		GameSignals.building_destroyed.emit(self)


func remove():
	collision_shape.disabled = true
	queue_free()


func _ready():
	name = name + str(building_index) + str(player_index)
	stats_manager.stats.changed.connect(_on_stats_changed)
	stats_manager.stat_changed.connect(_on_stat_changed)


func _on_stats_changed() -> void:
	pass


func _on_stat_changed(_stat_type, _stat_value) -> void:
	pass


func _get_is_placed() -> bool:
	return is_placed


func _set_is_placed(value : bool):
	#print(name, " is placed: ", value)
	if is_placed == value:
		return
		
	is_placed = value
	
	if is_placed:
		_enable_tower()


func _enable_tower() -> void:
	collision_shape.disabled = false
	if not is_in_group(GroupNames.BUILDINGS):
		add_to_group(GroupNames.BUILDINGS)
	if not is_in_group(GroupNames.SELECTABLE):
		add_to_group(GroupNames.SELECTABLE)


func _get_is_valid_placement() -> bool:
	return is_valid_placement


func _set_is_valid_placement(value : bool) -> void:
	is_valid_placement = value
	if is_valid_placement:
		show()
	else:
		hide()
	BuildingPlacementDrawer.draw_building(collision_shape.shape.get_rect(), position, is_valid_placement, is_placing)


func _get_is_placing() -> bool:
	return is_placing


func _set_is_placing(value : bool) -> void:
	if is_placing == value:
		return
		
	is_placing = value
	
	if not is_placing:
		BuildingPlacementDrawer.draw_building(collision_shape.shape.get_rect(), collision_shape.position, is_valid_placement, is_placing)
	else:
		if collision_shape == null:
			collision_shape = $CollisionShape2D
		collision_shape.disabled = true


func _get_corners() -> Array[Vector2]:
	var rect : Rect2 = collision_shape.shape.get_rect()
	var half_extends : Vector2 = rect.size * 0.5
	var vector_array : Array[Vector2] = []
	vector_array.append(position - half_extends)
	vector_array.append(Vector2(position.x + half_extends.x, position.y - half_extends.y))
	vector_array.append(Vector2(position.x - half_extends.x, position.y + half_extends.y))
	vector_array.append(position + half_extends)
	return vector_array


func _get_stats_manager() -> StatsManager:
	if has_node("StatsManager"):
		return $StatsManager
	stats_manager = StatsManager.new()
	stats_manager.base_stats = ResourceLoader.load(PATH_TO_STAT_RESOURCE + stats_resource_name)
	stats_manager.name = "StatsManager"
	add_child(stats_manager)
	return stats_manager


func _get_stats_resource_name() -> String:
	return name.rstrip("0123456789").to_snake_case().to_lower() + "_stats.tres"
	
