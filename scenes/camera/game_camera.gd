class_name GameCamera
extends Camera2D

@export var move_speed = 2
@export var move_lerp_weight = 100
@export var pan_sensitivity = 0.1
@export var pan_speed = 0.2
@export var pan_min_distance = 20
@export var zoom_speed = Vector2(0.1, 0.1)
@export var zoom_min = Vector2(1, 1)
@export var zoom_max = Vector2(5,5)
@export var zoom_lerp_weight = 100
@export var limit_l : int = -1500
@export var limit_r : int = 1500
@export var limit_b : int = 1500
@export var limit_u : int = -1500
enum CameraMode {Static, Free}
var move_target_position = Vector2.ZERO
var zoom_target_position = Vector2.ZERO
var fixed_toggle_position = Vector3.ZERO
var pan_initial_position = Vector2.ZERO
var pan_current_position = Vector2.ZERO
var pan_end_position = Vector2.ZERO
var is_panning : bool = false
var current_mode : CameraMode = CameraMode.Static


func _ready():
	limit_left = limit_l
	limit_right = limit_r
	limit_bottom = limit_b
	limit_top = limit_u


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if current_mode == CameraMode.Static:
		return
		
	_movement(delta)
	_zoom(delta)
	_pan(delta)
	
	
func _movement(delta):
	if Input.is_action_pressed("MoveCameraLeft") and Input.is_action_pressed("MoveCameraUp"):
		move_target_position = global_position + (Vector2.LEFT + Vector2.UP) * move_speed
	elif Input.is_action_pressed("MoveCameraLeft") and Input.is_action_pressed("MoveCameraDown"):
		move_target_position = global_position + (Vector2.LEFT + Vector2.DOWN) * move_speed
	elif Input.is_action_pressed("MoveCameraRight") and Input.is_action_pressed("MoveCameraUp"):
		move_target_position = global_position + (Vector2.RIGHT + Vector2.UP) * move_speed
	elif Input.is_action_pressed("MoveCameraRight") and Input.is_action_pressed("MoveCameraDown"):
		move_target_position = global_position + (Vector2.RIGHT + Vector2.DOWN) * move_speed
	elif Input.is_action_pressed("MoveCameraLeft"):
		move_target_position = global_position + Vector2.LEFT * move_speed
	elif Input.is_action_pressed("MoveCameraRight"):
		move_target_position = global_position + Vector2.RIGHT * move_speed
	elif Input.is_action_pressed("MoveCameraUp"):
		move_target_position = global_position + Vector2.UP * move_speed
	elif Input.is_action_pressed("MoveCameraDown"):
		move_target_position = global_position + Vector2.DOWN * move_speed
	else:
		move_target_position = global_position
	_move_camera_smoothly(move_target_position, delta)
	
	
func _zoom(delta):
	if Input.is_action_just_released("ZoomCameraOut"):
		if zoom > zoom_min:
			zoom_target_position = zoom - zoom_speed
	elif Input.is_action_just_released("ZoomCameraIn"):
		if zoom < zoom_max:
			zoom_target_position = zoom + zoom_speed
	else:
		zoom_target_position = zoom
	_zoom_camera_smoothly(zoom_target_position, delta)
	
	
func _move_camera_smoothly(targetPosition, delta):
	position = lerp(position, targetPosition, move_lerp_weight * delta)
	
	
func _zoom_camera_smoothly(targetPosition, delta):
	zoom = lerp(zoom, targetPosition, zoom_lerp_weight * delta)


func _pan(delta):
	if Input.is_action_just_pressed("PanCamera"):
		pan_initial_position = get_viewport().get_mouse_position()
		is_panning = true
		
	if Input.is_action_just_released("PanCamera"):
		pan_end_position = get_viewport().get_mouse_position()
		is_panning = false
		
	if is_panning:
		pan_current_position = get_viewport().get_mouse_position()
		var from_initial_to_current = pan_current_position - pan_initial_position
		var distance = from_initial_to_current.length()
		if (pan_current_position != pan_initial_position) and (distance > pan_min_distance):
			var direction_to_current = -from_initial_to_current.normalized()
			position.x = clamp(lerp(position.x, position.x + direction_to_current.x * pan_speed * distance * pan_sensitivity, move_lerp_weight * delta), limit_left, limit_right)
			position.y = clamp(lerp(position.y, position.y + direction_to_current.y * pan_speed * distance * pan_sensitivity, move_lerp_weight * delta), limit_top, limit_bottom)
