class_name PathPreview
extends Node2D

## Marks every spawn point and castle, and draws the dotted enemy routes between them while the
## player builds. The routes follow the maze as buildings change the grid and hide during a wave.
## A spawner with a flight_route also shows the flyers' route, in its own colour with wider dots.

const DOT_SPACING : float = 8.0
const FLIGHT_DOT_SPACING : float = 12.0
const DOT_SIZE : Vector2 = Vector2(2, 2)
const SPAWN_RADIUS : float = 6.0
const END_RADIUS : float = 9.0
const MARKER_WIDTH : float = 2.0
const MARKER_POINTS : int = 24
const CENTER_DOT_SIZE : Vector2 = Vector2(4, 4)
#the ground tile layers are at -1; drawn after them, so units and trees stay on top
const GROUND_Z_INDEX : int = -1

@export var path_color : Color = Color(1.0, 0.85, 0.4, 0.7)
@export var spawn_color : Color = Color(1.0, 0.35, 0.3, 0.9)
@export var end_color : Color = Color(0.45, 0.8, 1.0, 0.9)
@export var flight_color : Color = Color(0.95, 0.5, 1.0, 0.95)

var paths : Array[PackedVector2Array] = []
#spawn, route points, castle: the corners only, without the flyers' wave
var flight_paths : Array[PackedVector2Array] = []
var is_route_visible : bool = true :
	set = _set_is_route_visible

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level


func _ready() -> void:
	z_index = GROUND_Z_INDEX
	GameSignals.astar_grid_updated.connect(_update_paths)
	GameSignals.wave_cleared.connect(_on_wave_cleared)
	UISignals.start_wave_pressed.connect(_on_start_wave_pressed)
	_update_paths()


func _update_paths() -> void:
	paths.clear()

	for route in level.get_routes():
		paths.append(level.grid.find_path(route[0], route[1]))

	flight_paths.clear()
	for spawner in level.get_spawners():
		if spawner.flight_route == null or spawner.end_point == null:
			continue
		var corners : PackedVector2Array = [spawner.global_position]
		corners.append_array(spawner.get_flight_route_points())
		corners.append(spawner.end_point.global_position)
		flight_paths.append(corners)

	queue_redraw()


func _draw() -> void:
	for path in paths:
		if path.is_empty():
			continue

		_draw_marker(path[0], SPAWN_RADIUS, spawn_color)
		_draw_marker(path[path.size() - 1], END_RADIUS, end_color)

		if not is_route_visible:
			continue

		_draw_dots(path, DOT_SPACING, path_color)

	if is_route_visible:
		for path in flight_paths:
			_draw_dots(path, FLIGHT_DOT_SPACING, flight_color)


func _draw_dots(path : PackedVector2Array, spacing : float, color : Color) -> void:
	for i in range(path.size() - 1):
		var from : Vector2 = to_local(path[i])
		var to : Vector2 = to_local(path[i + 1])
		var steps : int = maxi(1, roundi(from.distance_to(to) / spacing))
		for step in steps:
			draw_rect(Rect2(from.lerp(to, float(step) / steps) - DOT_SIZE * 0.5, DOT_SIZE), color)


func _draw_marker(world_position : Vector2, radius : float, color : Color) -> void:
	var center : Vector2 = to_local(world_position)
	draw_arc(center, radius, 0.0, TAU, MARKER_POINTS, color, MARKER_WIDTH)
	draw_rect(Rect2(center - CENTER_DOT_SIZE * 0.5, CENTER_DOT_SIZE), color)


func _set_is_route_visible(value : bool) -> void:
	if is_route_visible == value:
		return

	is_route_visible = value
	queue_redraw()


func _on_start_wave_pressed() -> void:
	is_route_visible = false


func _on_wave_cleared(_wave_number : int) -> void:
	is_route_visible = true
	_update_paths()
