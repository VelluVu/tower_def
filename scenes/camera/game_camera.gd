class_name GameCamera
extends Camera2D


const MOVE_LEFT_ACTION_NAME : String = "MoveCameraLeft"
const MOVE_RIGHT_ACTION_NAME : String = "MoveCameraRight"
const MOVE_UP_ACTION_NAME : String = "MoveCameraUp"
const MOVE_DOWN_ACTION_NAME : String = "MoveCameraDown"
const ZOOM_OUT_ACTION_NAME : String = "ZoomCameraOut"
const ZOOM_IN_ACTION_NAME : String = "ZoomCameraIn"
const PAN_ACTION_NAME : String = "PanCamera"
## GameCursor shows the grabbing claw while the camera is dragged.
const CURSOR_SOURCE : StringName = &"camera_pan"
## How close to the window edge the mouse scrolls the camera, in viewport pixels.
const EDGE_SCROLL_MARGIN : float = 4.0
## A leak shakes the view this many world pixels (a boss twice as far) for SHAKE_SECONDS.
const SHAKE_PIXELS : float = 1.0
const BOSS_SHAKE_PIXELS : float = 2.0
## A boss falling shakes harder than anything else.
const BOSS_DEFEATED_SHAKE_PIXELS : float = 3.0
const SHAKE_SECONDS : float = 0.24
## New shake position every this many seconds, so the shake reads as a few jolts, not a blur.
const SHAKE_STEP_SECONDS : float = 0.04
## A glide to an event (a boss arriving, a leak out of view) moves this share of the way per
## second's worth of move_speed, slower than the keys so it reads as the camera being led.
const GLIDE_SPEED_FACTOR : float = 0.45
## A glide ends this close to its point, in world pixels.
const GLIDE_DONE_DISTANCE : float = 1.0
## After a leak glide, further leaks for this many seconds leave the camera where it is.
const LEAK_GLIDE_COOLDOWN_SECONDS : float = 8.0

enum CameraMode {Static, Free}

@export var move_step : float = 16
@export var move_speed : float = 10
@export var zoom_min = Vector2(1, 1)
@export var zoom_max = Vector2(3, 3)
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
var move_target_position : Vector2 = Vector2.ZERO
var fixed_toggle_position = Vector3.ZERO
#the drag holds the world point under the mouse: where the mouse and the camera were at the grab
var pan_initial_position : Vector2 = Vector2.ZERO
var pan_start_camera_position : Vector2 = Vector2.ZERO
var move_direction : Vector2 = Vector2.ZERO

#the widest zoom in the current level: the level always fills the view's width
var level_min_zoom : float = 1.0
#from the settings: a multiplier on move_step, and whether the window edge scrolls
var speed_multiplier : float = 1.0
var is_edge_scroll_on : bool = false
#the last mouse position stays inside the edge margin after the mouse leaves the window
var is_mouse_in_window : bool = true
#the wheel over a panel belongs to the panel, not the zoom
var is_cursor_on_gui : bool = false

var is_panning : bool = false :
	set = _set_is_panning

var current_mode : CameraMode = CameraMode.Static

var is_shake_on : bool = true
var shake_time_left : float = 0.0
var shake_step_left : float = 0.0
var shake_pixels : float = 0.0
#whole world pixels, added to the view's snap offset
var shake_offset : Vector2 = Vector2.ZERO

var is_follow_events_on : bool = true
#the camera's own key or drag input ends a glide at once
var is_gliding : bool = false
var glide_target : Vector2 = Vector2.ZERO
var leak_glide_cooldown_left : float = 0.0
#a glide would move the world under a building in hand or a wall line being dragged
var is_placing_building : bool = false
#kept from the level's load for the frame-the-level key
var level_path_bounds : Rect2 = Rect2()


func _ready() -> void:
	GameSignals.level_loaded.connect(_on_level_loaded)
	UISignals.mouse_on_gui.connect(_on_mouse_on_gui)
	SettingsManager.option_changed.connect(_on_option_changed)
	speed_multiplier = SettingsManager.get_option(SettingsManager.OPTION_CAMERA_SPEED)
	is_edge_scroll_on = SettingsManager.get_option(SettingsManager.OPTION_EDGE_SCROLL)
	is_shake_on = SettingsManager.get_option(SettingsManager.OPTION_SCREEN_SHAKE)
	is_follow_events_on = SettingsManager.get_option(SettingsManager.OPTION_CAMERA_FOLLOWS_EVENTS)
	InputManager.shortcut_pressed.connect(_on_shortcut_pressed)
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.building_placement_change.connect(_on_building_placement_change)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reached_end_point)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	move_target_position = global_position


func _process(delta: float) -> void:
	if current_mode == CameraMode.Static:
		return
	
	#keys typed into a text field (the console) must not move the camera
	if get_viewport().gui_get_focus_owner() is LineEdit:
		move_direction = Vector2.ZERO
		is_panning = false
	else:
		_zoom()
		_movement()
		_pan()
	leak_glide_cooldown_left = maxf(0.0, leak_glide_cooldown_left - delta)
	_move_camera_smoothly(delta)
	_update_shake(delta)
	_snap_view_to_art_pixels()


#the lerps keep the exact position; only the view is shifted onto whole world pixels,
#so at 2x and 3x the tiles and units never sit half an art pixel off
func _snap_view_to_art_pixels() -> void:
	offset = global_position.round() - global_position + shake_offset


func shake(pixels : float) -> void:
	if not is_shake_on:
		return
	shake_pixels = maxf(pixels, shake_pixels if shake_time_left > 0.0 else 0.0)
	shake_time_left = SHAKE_SECONDS
	shake_step_left = 0.0


func _update_shake(delta : float) -> void:
	if shake_time_left <= 0.0:
		shake_offset = Vector2.ZERO
		return
	shake_time_left -= delta
	shake_step_left -= delta
	if shake_step_left > 0.0:
		return
	shake_step_left = SHAKE_STEP_SECONDS
	var direction : Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	shake_offset = (direction * shake_pixels).round()


func _on_enemy_reached_end_point(enemy : Enemy) -> void:
	shake(BOSS_SHAKE_PIXELS if enemy.is_boss else SHAKE_PIXELS)
	if leak_glide_cooldown_left > 0.0 or is_point_in_view(enemy.global_position):
		return
	if glide_to(enemy.global_position):
		leak_glide_cooldown_left = LEAK_GLIDE_COOLDOWN_SECONDS


#deferred: the spawner places the enemy after it enters the tree
func _on_enemy_spawned(enemy : Enemy) -> void:
	if enemy.is_boss:
		_glide_to_enemy.call_deferred(enemy)


func _glide_to_enemy(enemy : Enemy) -> void:
	if is_instance_valid(enemy):
		glide_to(enemy.global_position)


## Leads the view to a world point at the current zoom; the player's own camera input ends it.
## Returns whether a glide started (off in the options, or before the level is framed, it does not).
func glide_to(world_point : Vector2) -> bool:
	if not is_follow_events_on or current_mode != CameraMode.Free or is_panning or is_placing_building 			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	glide_target = _clamp_to_limits(world_point)
	is_gliding = true
	return true


func is_point_in_view(world_point : Vector2) -> bool:
	var half_view : Vector2 = get_viewport_rect().size * 0.5 / zoom
	return Rect2(global_position - half_view, half_view * 2.0).has_point(world_point)


## Back to the level's start view: the spawners and the castles in sight.
func frame_level() -> void:
	if current_mode != CameraMode.Free:
		return
	is_gliding = false
	_frame_level(level_path_bounds)


func _on_building_placement_change(is_placing : bool) -> void:
	is_placing_building = is_placing
	if is_placing:
		is_gliding = false


func _on_shortcut_pressed(action : StringName) -> void:
	if action == InputManager.ACTION_FRAME_LEVEL:
		frame_level()


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if enemy.is_boss:
		shake(BOSS_DEFEATED_SHAKE_PIXELS)


func _zoom() -> void:
	if is_cursor_on_gui:
		return
	var steps : float = 0.0
	if Input.is_action_just_pressed(ZOOM_IN_ACTION_NAME):
		steps += zoom_step
	if Input.is_action_just_pressed(ZOOM_OUT_ACTION_NAME):
		steps -= zoom_step
	if steps == 0.0:
		return
	var min_zoom : float = _get_min_zoom()
	var new_zoom : float = clampf(roundf(zoom.x + steps), min_zoom, maxf(min_zoom, zoom_max.x))
	if new_zoom == zoom.x:
		return
	_zoom_at(_get_zoom_anchor(), new_zoom)


#no tween: a fractional zoom between the whole steps makes the pixel art shimmer
func _zoom_at(screen_point : Vector2, new_zoom : float) -> void:
	var from_center : Vector2 = screen_point - get_viewport_rect().size * 0.5
	var world_point : Vector2 = global_position + from_center / zoom
	#the player's own zoom ends a glide: its target was clamped to the old zoom's limits
	is_gliding = false
	zoom = Vector2.ONE * new_zoom
	global_position = _clamp_to_limits(world_point - from_center / zoom)
	move_target_position = global_position
	if is_panning:
		pan_initial_position = get_viewport().get_mouse_position()
		pan_start_camera_position = global_position


#the wheel zooms at the cursor; a key with the mouse outside the view zooms at the centre
#(an embedded or unfocused window can report a cursor far outside the view)
func _get_zoom_anchor() -> Vector2:
	var mouse_position : Vector2 = get_viewport().get_mouse_position()
	if is_mouse_in_window and get_viewport_rect().has_point(mouse_position):
		return mouse_position
	return get_viewport_rect().size * 0.5


func _get_min_zoom() -> float:
	return maxf(zoom_min.x, level_min_zoom)


func _clamp_to_limits(target : Vector2) -> Vector2:
	var viewport_half : Vector2 = get_viewport_rect().size * 0.5 / zoom
	var limit_min : Vector2 = Vector2(limit_left + viewport_half.x, limit_top + viewport_half.y)
	var limit_max : Vector2 = Vector2(limit_right - viewport_half.x, limit_bottom - viewport_half.y)
	return target.clamp(limit_min, limit_max)


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
	elif key == SettingsManager.OPTION_SCREEN_SHAKE:
		is_shake_on = value
	elif key == SettingsManager.OPTION_CAMERA_FOLLOWS_EVENTS:
		is_follow_events_on = value
		if not is_follow_events_on:
			is_gliding = false

func _move_camera_smoothly(delta : float) -> void:
	if is_panning:
		is_gliding = false
		return
	if is_gliding and move_direction != Vector2.ZERO:
		is_gliding = false
	if is_gliding:
		_glide(delta)
		return
	#divided by the zoom so the screen scrolls equally fast at 1x and 3x
	var step : float = move_step * speed_multiplier / zoom.x
	move_target_position = _clamp_to_limits(global_position + move_direction * step)
	global_position = _clamp_to_limits(global_position.lerp(move_target_position, move_speed * delta))


func _glide(delta : float) -> void:
	var weight : float = minf(1.0, move_speed * GLIDE_SPEED_FACTOR * delta)
	global_position = _clamp_to_limits(global_position.lerp(glide_target, weight))
	move_target_position = global_position
	if global_position.distance_to(glide_target) <= GLIDE_DONE_DISTANCE:
		global_position = glide_target
		is_gliding = false


#grab and drag: the world point under the mouse stays under it
func _pan() -> void:
	is_panning = Input.is_action_pressed(PAN_ACTION_NAME)
	if not is_panning:
		return
	var dragged : Vector2 = get_viewport().get_mouse_position() - pan_initial_position
	global_position = _clamp_to_limits(pan_start_camera_position - dragged / zoom)
	move_target_position = global_position


func _set_is_panning(value : bool) -> void:
	if is_panning == value:
		return
	is_panning = value
	UISignals.cursor_mode_requested.emit(CURSOR_SOURCE, GameCursor.Mode.GRAB if is_panning else GameCursor.Mode.POINTER)
	if is_panning:
		pan_initial_position = get_viewport().get_mouse_position()
		pan_start_camera_position = global_position


func _on_level_loaded(level : Level) -> void:
	#a menu freed under the cursor may never send mouse_on_gui(false)
	is_cursor_on_gui = false
	var half_size : Vector2 = level.tiles.background_pixel_size.round()
	var viewport_size : Vector2 = get_viewport_rect().size
	#rounded up to a whole zoom so the level still fills the view's width
	level_min_zoom = ceilf(maxf(zoom_min.x, viewport_size.x / (half_size.x * 2.0)))
	#a level lower than the view at the widest zoom gets the backdrop above and below it
	half_size.y = maxf(half_size.y, ceilf(viewport_size.y / level_min_zoom * 0.5))
	#whole pixels already (rounded above), so the int limits lose nothing
	limit_left = -roundi(half_size.x)
	limit_top = -roundi(half_size.y)
	limit_right = roundi(half_size.x)
	limit_bottom = roundi(half_size.y)
	is_gliding = false
	level_path_bounds = level.get_path_bounds()
	_frame_level(level_path_bounds)
	current_mode = CameraMode.Free


## Starts the level with the spawners and the end points in view.
func _frame_level(bounds : Rect2) -> void:
	var framed : Rect2 = bounds.grow(level_frame_margin)
	var viewport_size : Vector2 = get_viewport_rect().size
	var fit : float = minf(viewport_size.x / framed.size.x, viewport_size.y / framed.size.y)
	#rounded down to a whole zoom so the framed path stays in view
	var start_zoom : float = clampf(floorf(fit), level_min_zoom, maxf(level_min_zoom, level_frame_max_zoom))
	zoom = Vector2.ONE * start_zoom
	global_position = _clamp_to_limits(framed.get_center())
	move_target_position = global_position


func _on_mouse_on_gui(value : bool) -> void:
	is_cursor_on_gui = value
