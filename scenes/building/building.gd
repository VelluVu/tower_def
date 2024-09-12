class_name Building
extends StaticBody2D

@onready var sprite : Sprite2D = $Sprite2D
@onready var collision_shape : CollisionShape2D = $CollisionShape2D
@export var player_index : int = 0
@export var closest_point_distance_limit : float = 0.9
@export var durability : int = 10
var building_index : int = 0
var is_overlapping_area : bool = false
var is_overlapping_body : bool = false


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
		else:
			if collision_shape == null:
				collision_shape = $CollisionShape2D
			collision_shape.disabled = true

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


func take_damage(damage : int):
	durability -= damage
	if durability <= 0:
		GameSignals.building_destroyed.emit(self)


func _ready():
	name = name + str(building_index) + str(player_index)
	add_to_group(GroupNames.buildings)


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
