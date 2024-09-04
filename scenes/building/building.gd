class_name Building
extends StaticBody2D

@onready var sprite : Sprite2D = $Sprite2D
@onready var collision_shape : CollisionShape2D = $CollisionShape2D
@export var player_index : int = 0
@export var closest_point_distance_limit : float = 0.9
var building_index : int = 0
var is_overlapping_area : bool = false
var is_overlapping_body : bool = false
var grid_position : Vector2
#var is_top_left_on_map : bool = false
#var is_top_right_on_map : bool = false
#var is_bottom_right_on_map : bool = false
#var is_bottom_left_on_map : bool = false
#var overlapping_areas : Array[Area2D]
#var overlapping_bodies : Array[Node2D]

var is_valid_placement : bool :
	get:
		return is_valid_placement
	set(value):
		is_valid_placement = value
		if is_valid_placement:
			show()
		else:
			hide()
		BuildingPlacementDrawer.draw_building(collision_shape.shape.get_rect(), position, is_valid_placement, is_placing)

var is_placing : bool :
	get: 
		return is_placing 
	set(value):
		if is_placing == value:
			return
		is_placing = value
		if not is_placing:
			BuildingPlacementDrawer.draw_building(collision_shape.shape.get_rect(), collision_shape.position, is_valid_placement, is_placing)

var is_placed : bool:
	get = get_is_placed,
	set = set_is_placed

var corners : Array[Vector2] : 
	get: 
		var rect : Rect2 = collision_shape.shape.get_rect()
		var half_extends : Vector2 = rect.size * 0.5
		var vector_array : Array[Vector2] = []
		vector_array.append(position - half_extends)
		vector_array.append(Vector2(position.x + half_extends.x, position.y - half_extends.y))
		vector_array.append(Vector2(position.x - half_extends.x, position.y + half_extends.y))
		vector_array.append(position + half_extends)
		return vector_array


func _ready():
	name = name + str(building_index) + str(player_index)



#func _process(_delta):
	#if is_placed:
		#return
	#
	#var rect := collision_shape.shape.get_rect()
	#var top_left : Vector2 = rect.position + global_position + Vector2(0, rect.position.y)
	#var top_right : Vector2 = Vector2(rect.end.x, rect.position.y) + global_position + Vector2(0, rect.position.y)
	#var bottom_right : Vector2 = rect.end + global_position + Vector2(0, rect.position.y)
	#var bottom_left : Vector2 = Vector2(rect.position.x, rect.end.y) + global_position + Vector2(0, rect.position.y)
	#
	#var map := get_world_2d().navigation_map
	#is_top_left_on_map = is_point_on_navigation_map(top_left, map)
	#is_top_right_on_map = is_point_on_navigation_map(top_right, map)
	#is_bottom_right_on_map = is_point_on_navigation_map(bottom_right, map)
	#is_bottom_left_on_map = is_point_on_navigation_map(bottom_left, map)
	#
	#is_overlapping_area = not (is_top_left_on_map and is_top_right_on_map and is_bottom_right_on_map and is_bottom_left_on_map)


#func is_point_on_navigation_map(point : Vector2, map : RID) -> bool:
	#var closest_point := NavigationServer2D.map_get_closest_point(map, point)
	#var delta := closest_point - point
	#var delta_length : float = delta.length()
	#var is_on_map = (delta_length < closest_point_distance_limit and delta_length > -closest_point_distance_limit)
	#return is_on_map


func get_is_placed() -> bool:
	return is_placed


func set_is_placed(value : bool):
	#print(name, " is placed: ", value)
	if is_placed == value:
		return
	is_placed = value
	if value:
		collision_shape.disabled = false


func remove():
	collision_shape.disabled = true
	queue_free()
