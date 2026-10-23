class_name GameCamera
extends Camera2D


const MOVE_LEFT_ACTION_NAME : String = "MoveCameraLeft"
const MOVE_RIGHT_ACTION_NAME : String = "MoveCameraRight"
const MOVE_UP_ACTION_NAME : String = "MoveCameraUp"
const MOVE_DOWN_ACTION_NAME : String = "MoveCameraDown"
const ZOOM_OUT_ACTION_NAME : String = "ZoomCameraOut"
const ZOOM_IN_ACTION_NAME : String = "ZoomCameraIn"
const PAN_ACTION_NAME : String = "PanCamera"
## How close to the window edge the mouse scrolls the camera, in viewport pixels.
const EDGE_SCROLL_MARGIN : float = 4.0
## Below this distance the zoom tween snaps to its whole-number target.
const ZOOM_SNAP_DISTANCE : float = 0.01

enum CameraMode {Static, Free}

@export var move_step : float = 16
@export var move_speed : float = 10
@export var pan_step : float = 16
@export var pan_speed : float = 10
@export var zoom_speed : float = 10
@export var zoom_min = Vector2(1, 1)
@export var zoom_max = Vector2(5,5)
@export var pan_speed_scale : float = 20.0
## Space kept around the spawners and end points when a level starts, in world pixels.
@export var level_frame_margin : float = 48.0
## The start view zooms out to fit the path, but never closer than this.
@export var level_frame_max_zoom : float = 2.0

#whole zoom steps keep every art pixel the same number of screen pixels
var zoom_step : float = 1.0
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

#the widest zoom in the current level: the level always fills the view's width
var level_min_zoom : float = 1.0
#from the settings: a multiplier on move_step, and whether the window edge scrolls
var speed_multiplier : float = 1.0
var is_edge_scroll_on : bool = false
#the last mouse position stays inside the edge margin after the mouse leaves the window
var is_mouse_in_window : bool = true

var is_panning : bool = false :
	set = _set_is_panning

var current_mode : CameraMode = CameraMode.Static


func _ready() -> void:
	GameSignals.level_loaded.connect(_on_level_loaded)
	SettingsManager.option_changed.connect(_on_option_changed)
	speed_multiplier = SettingsManager.get_option(SettingsManager.OPTION_CAMERA_SPEED)
	is_edge_scroll_on = SettingsManager.get_option(SettingsManager.OPTION_EDGE_SCROLL)
	zoom_target_position = zoom
	move_target_position = global_position
	pan_initial_position = global_position
	pan_lerp_target_pos = global_position


func _process(delta: float) -> void:
	if current_mode == CameraMode.Static:
		return
	
	#keys typed into a text field (the console) must not move the camera
	if get_viewport().gui_get_focus_owner() is LineEdit:
		move_direction = Vector2.ZERO
	else:
		_zoom()
		_movement()
	_pan()
	_move_camera_smoothly(delta)
	_zoom_camera_smoothly(delta)
	_pan_camera_smoothly(delta)


func _zoom() -> void:
	if Input.is_action_just_pressed(ZOOM_IN_ACTION_NAME):
		zoom_target_position = (zoom_target_position + Vector2.ONE * zoom_step).round()
	if Input.is_action_just_pressed(ZOOM_OUT_ACTION_NAME):
		zoom_target_position = (zoom_target_position - Vector2.ONE * zoom_step).round()


func _movement() -> void:
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
		move_direction = _get_edge_scroll_direction()


func _get_edge_scroll_direction() -> Vector2:
	if not is_edge_scroll_on or not is_mouse_in_window or not get_window().has_focus():
		return Vector2.ZERO

	var mouse_position : Vector2 = get_viewport().get_mouse_position()
	var viewport_size : Vector2 = get_viewport_rect().size
	var direction : Vector2 = Vector2.ZERO

	if mouse_position.x <= EDGE_SCROLL_MARGIN:
		direction.x = -1.0
	elif mouse_position.x >= viewport_size.x - EDGE_SCROLL_MARGIN:
		direction.x = 1.0
	if mouse_position.y <= EDGE_SCROLL_MARGIN:
		direction.y = -1.0
	elif mouse_position.y >= viewport_size.y - EDGE_SCROLL_MARGIN:
		direction.y = 1.0

	return direction


func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		is_mouse_in_window = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		is_mouse_in_window = false


func _on_option_changed(key : String, value : Variant) -> void:
	if key == SettingsManager.OPTION_CAMERA_SPEED:
		speed_multiplier = value
	elif key == SettingsManager.OPTION_EDGE_SCROLL:
		is_edge_scroll_on = value

func _zoom_camera_smoothly(delta : float) -> void:
	var min_zoom : Vector2 = Vector2.ONE * maxf(zoom_min.x, level_min_zoom)
	zoom_target_position = clamp(zoom_target_position, min_zoom, zoom_max)
	zoom = zoom.lerp(zoom_target_position, zoom_speed * delta)
	if zoom.distance_to(zoom_target_position) < ZOOM_SNAP_DISTANCE:
		zoom = zoom_target_position
	zoom = zoom.clamp(min_zoom, zoom_max)


func _move_camera_smoothly(delta : float) -> void:
	if is_panning:
		return
		
	var viewport_half = get_viewport_rect().size * 0.5 * ( Vector2.ONE / zoom )
	var limit_min = Vector2(limit_left + viewport_half.x, limit_top + viewport_half.y)
	var limit_max = Vector2(limit_right - viewport_half.x, limit_bottom - viewport_half.y)
	
	move_target_position = global_position + move_direction * move_step * speed_multiplier
	move_target_position = move_target_position.clamp(limit_min, limit_max)
	global_position = global_position.lerp(move_target_position, move_speed * delta)
	global_position = global_position.clamp(limit_min, limit_max)


func _pan() -> void:
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


func _pan_camera_smoothly(delta : float) -> void:
	if not is_panning:
		return
		
	var viewport_half = get_viewport_rect().size * 0.5 * ( Vector2.ONE / zoom )
	var limit_min = Vector2(limit_left + viewport_half.x, limit_top + viewport_half.y)
	var limit_max = Vector2(limit_right - viewport_half.x, limit_bottom - viewport_half.y)
	pan_lerp_target_pos = pan_lerp_target_pos.clamp(limit_min, limit_max)
	global_position = global_position.slerp(pan_lerp_target_pos, pan_speed * pan_speed_scale * delta)
	global_position = global_position.clamp(limit_min, limit_max)


func _on_level_loaded(level : Level) -> void:
	var half_size : Vector2 = level.tiles.background_pixel_size.round()
	var viewport_size : Vector2 = get_viewport_rect().size
	#rounded up to a whole zoom so the level still fills the view's width
	level_min_zoom = ceilf(maxf(zoom_min.x, viewport_size.x / (half_size.x * 2.0)))
	#a level lower than the view at the widest zoom gets the backdrop above and below it
	half_size.y = maxf(half_size.y, ceilf(viewport_size.y / level_min_zoom * 0.5))
	limit_left = -half_size.x
	limit_top = -half_size.y
	limit_right = half_size.x
	limit_bottom = half_size.y
	_frame_level(level.get_path_bounds())
	current_mode = CameraMode.Free


## Starts the level with the spawners and the end points in view.
func _frame_level(bounds : Rect2) -> void:
	var framed : Rect2 = bounds.grow(level_frame_margin)
	var viewport_size : Vector2 = get_viewport_rect().size
	var fit : float = minf(viewport_size.x / framed.size.x, viewport_size.y / framed.size.y)
	#rounded down to a whole zoom so the framed path stays in view
	var start_zoom : float = clampf(floorf(fit), level_min_zoom, maxf(level_min_zoom, level_frame_max_zoom))
	zoom = Vector2.ONE * start_zoom
	zoom_target_position = zoom

	var viewport_half : Vector2 = viewport_size * 0.5 / zoom
	var limit_min : Vector2 = Vector2(limit_left + viewport_half.x, limit_top + viewport_half.y)
	var limit_max : Vector2 = Vector2(limit_right - viewport_half.x, limit_bottom - viewport_half.y)
	global_position = framed.get_center().clamp(limit_min, limit_max)
	move_target_position = global_position
	pan_lerp_target_pos = global_position
