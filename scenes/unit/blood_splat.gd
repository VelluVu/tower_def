class_name BloodSplat
extends Node2D


@onready var live_timer : CustomTimer = $LiveTimer

@export var textures : Array[Texture2D]
@export var life_time : float = 15.0

var texture_to_draw : Texture2D
var is_draw : bool :
	set = _set_is_draw


func splat(_pos : Vector2) -> void:
	if not live_timer.timeout.is_connected(_on_life_time_end):
		live_timer.timeout.connect(_on_life_time_end)
	live_timer.base_wait_time = life_time
	global_position = _pos
	is_draw = true


func clean() -> void:
	is_draw = false
	queue_redraw()


func _set_is_draw(value : bool) -> void:
	if is_draw == value:
		return
		
	is_draw = value
	
	if is_draw:
		texture_to_draw = textures.pick_random()
		queue_redraw()
		live_timer.start()


func _on_life_time_end() -> void:
	clean()


func _draw() -> void:
	if not is_draw:
		return
		
	if texture_to_draw == null:
		return
		
	draw_texture(texture_to_draw, Vector2.ONE * (Utils.TILE_SIZE * -0.5))
