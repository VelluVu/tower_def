class_name PathPreview
extends Node2D

## Marks every spawn point and castle, and draws the dotted enemy routes between them while the
## player builds. The routes follow the maze as buildings change the grid and hide during a wave.

const DOT_SPACING : float = 8.0
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

var paths : Array[PackedVector2Array] = []
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

	for spawner in level.get_spawners():
		var end : Vector2 = spawner.end_point.global_position if spawner.end_point != null else level.end_point.global_position
		paths.append(level.grid.find_path(spawner.global_position, end))

	queue_redraw()


func _draw() -> void:
	for path in paths:
		if path.is_empty():
			continue

		_draw_marker(path[0], SPAWN_RADIUS, spawn_color)
		_draw_marker(path[path.size() - 1], END_RADIUS, end_color)

		if not is_route_visible:
			continue

		for i in range(path.size() - 1):
			var from : Vector2 = to_local(path[i])
			var to : Vector2 = to_local(path[i + 1])
			var steps : int = maxi(1, roundi(from.distance_to(to) / DOT_SPACING))
			for step in steps:
				draw_rect(Rect2(from.lerp(to, float(step) / steps) - DOT_SIZE * 0.5, DOT_SIZE), path_color)


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
