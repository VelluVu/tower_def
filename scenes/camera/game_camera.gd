class_name GameCamera
extends Camera2D


const MOVE_LEFT_ACTION_NAME : String = "MoveCameraLeft"
const MOVE_RIGHT_ACTION_NAME : String = "MoveCameraRight"
const MOVE_UP_ACTION_NAME : String = "MoveCameraUp"
const MOVE_DOWN_ACTION_NAME : String = "MoveCameraDown"
const ZOOM_OUT_ACTION_NAME : String = "ZoomCameraOut"
const ZOOM_IN_ACTION_NAME : String = "ZoomCameraIn"
const PAN_ACTION_NAME : String = "PanCamera"

enum CameraMode {Static, Free}

@export var move_step : float = 16
@export var move_speed : float = 10
@export var pan_step : float = 16
@export var pan_speed : float = 10
@export var zoom_speed : float = 10
@export var zoom_min = Vector2(1, 1)
@export var zoom_max = Vector2(5,5)

var zoom_in : float = 1.1
var zoom_out : float = 0.9
var original_delta : float = 0
var scaled_delta : float = 0
var current_delta : float = 0

var base_move_speed : float = 0
var move_lerp_start_position : Vector2 = Vector2.ZERO
var zoom_lerp_start_position : Vector2 = Vector2.ZERO
var move_target_position : Vector2 = Vector2.ZERO
var zoom_target_position : Vector2 = Vector2.ZERO
var fixed_toggle_position = Vector3.ZERO
var pan_initial_position : Vector2 = Vector2.ZERO
var pan_current_position : Vector2 = Vector2.ZERO
var pan_end_position : Vector2 = Vector2.ZERO
var pan_lerp_target_pos : Vector2 = Vector2.ZERO
var move_direction : Vector2 = Vector2.ZERO

var is_panning : bool = false :
	set = _set_is_panning

var current_mode : CameraMode = CameraMode.Static


func _ready():
	GameSignals.level_loaded.connect(_on_level_loaded)
	zoom_target_position = zoom
	move_target_position = global_position
	pan_initial_position = global_position
	pan_lerp_target_pos = global_position


func _process(delta: float) -> void:
	if current_mode == CameraMode.Static:
		return
	
	_zoom()
	_movement()
	_pan()
	_move_camera_smoothly(delta)
	_zoom_camera_smoothly(delta)
	_pan_camera_smoothly(delta)


func _zoom():
	if Input.is_action_just_pressed(ZOOM_IN_ACTION_NAME):
		zoom_target_position *= zoom_in 
	if Input.is_action_just_pressed(ZOOM_OUT_ACTION_NAME):
		zoom_target_position *= zoom_out


func _movement():
	if Input.is_action_pressed(MOVE_LEFT_ACTION_NAME) and Input.is_action_pressed(MOVE_UP_ACTION_NAME):
		move_direction = Vector2.LEFT + Vector2.UP
	elif Input.is_action_pressed(MOVE_LEFT_ACTION_NAME) and Input.is_action_pressed(MOVE_DOWN_ACTION_NAME):
		move_direction = Vector2.LEFT + Vector2.DOWN
	elif Input.is_action_pressed(MOVE_RIGHT_ACTION_NAME) and Input.is_action_pressed(MOVE_UP_ACTION_NAME):
		move_direction = Vector2.RIGHT + Vector2.UP
	elif Input.is_action_pressed(MOVE_RIGHT_ACTION_NAME) and Input.is_action_pressed(MOVE_DOWN_ACTION_NAME):
		move_direction = Vector2.RIGHT + Vector2.DOWN
	elif Input.is_action_pressed(MOVE_LEFT_ACTION_NAME):
		move_direction = Vector2.LEFT
	elif Input.is_action_pressed(MOVE_RIGHT_ACTION_NAME):
		move_direction = Vector2.RIGHT
	elif Input.is_action_pressed(MOVE_UP_ACTION_NAME):
		move_direction = Vector2.UP
	elif Input.is_action_pressed(MOVE_DOWN_ACTION_NAME):
		move_direction = Vector2.DOWN
	else:
		move_direction = Vector2.ZERO

func _zoom_camera_smoothly(delta : float):
	zoom_target_position = clamp(zoom_target_position, zoom_min, zoom_max)
	zoom = zoom.lerp(zoom_target_position, zoom_speed * delta)
	zoom = zoom.clamp(zoom_min, zoom_max)


func _move_camera_smoothly(delta : float):
	if is_panning:
		return
		
	var viewport_half = get_viewport_rect().size * 0.5 * ( Vector2.ONE / zoom )
	var limit_min = Vector2(limit_left + viewport_half.x, limit_top + viewport_half.y)
	var limit_max = Vector2(limit_right - viewport_half.x, limit_bottom - viewport_half.y)
	
	move_target_position = global_position + move_direction * move_step
	move_target_position = move_target_position.clamp(limit_min, limit_max)
	global_position = global_position.lerp(move_target_position, move_speed * delta)
	global_position = global_position.clamp(limit_min, limit_max)


func _pan():
	if Input.is_action_pressed(PAN_ACTION_NAME):
		is_panning = true
		pan_current_position = get_viewport().get_mouse_position()
		var from_initial_to_current = pan_current_position - pan_initial_position
		pan_lerp_target_pos = global_position - from_initial_to_current.normalized()
		
	if Input.is_action_just_released(PAN_ACTION_NAME):
		is_panning = false


func _set_is_panning(value : bool) -> void:
	if is_panning == value:
		return
		
	is_panning = value
	
	if is_panning:
		pan_initial_position = get_viewport().get_mouse_position()
	else:
		pan_end_position = get_viewport().get_mouse_position()


func _pan_camera_smoothly(delta : float):
	if not is_panning:
		return
		
	var viewport_half = get_viewport_rect().size * 0.5 * ( Vector2.ONE / zoom )
	var limit_min = Vector2(limit_left + viewport_half.x, limit_top + viewport_half.y)
	var limit_max = Vector2(limit_right - viewport_half.x, limit_bottom - viewport_half.y)
	pan_lerp_target_pos = pan_lerp_target_pos.clamp(limit_min, limit_max)
	global_position = global_position.lerp(pan_lerp_target_pos, pan_speed * delta)
	global_position = global_position.clamp(limit_min, limit_max)


func _on_level_loaded(level : Level) -> void:
	var bg_size : Vector2 = level.tiles.background_pixel_size
	var bg_size_x_rounded = round(bg_size.x)
	var bg_size_y_rounded = round(bg_size.y)
	limit_left = -bg_size_x_rounded
	limit_top = -bg_size_y_rounded
	limit_right = bg_size_x_rounded
	limit_bottom = bg_size_y_rounded
	current_mode = CameraMode.Free
