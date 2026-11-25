class_name RangeArea
extends Area2D

## Puffe's mint for a fine spot and a selected tower, Endesga 32 red where it cannot go.
const RING_COLOR : Color = Color("68ffd0")
const INVALID_RING_COLOR : Color = Color("e43b44")
const FILL_ALPHA : float = 0.12
const RING_ALPHA : float = 0.8
## Enough segments that the 1 px ring has no visible corners at the largest ranges.
const RING_POINTS : int = 64

@export var draw_range : bool = true
#what the last _draw showed, so a placing tower redraws only when it changes
var drawn_state : Vector3 = Vector3.ZERO
var actor : Node2D :
	get:
		if actor == null:
			actor = get_parent()
		return actor


func _ready() -> void:
	actor.selected.connect(_on_selected)


func _on_stats_changed() -> void:
	queue_redraw()


func _on_selected(is_selected : bool) -> void:
	queue_redraw()
	
	if not is_selected:
		if actor.stats_changed.is_connected(_on_stats_changed):
			actor.stats_changed.disconnect(_on_stats_changed)
		return
	
	if not actor.stats_changed.is_connected(_on_stats_changed):
		actor.stats_changed.connect(_on_stats_changed)
	


#while the player places a tower its reach follows the cursor, red where it cannot be built
func _process(_delta : float) -> void:
	if not draw_range:
		return
	var state : Vector3 = Vector3(float(_is_shown()), float(_is_valid()), actor.radius)
	if state != drawn_state:
		queue_redraw()


func _is_shown() -> bool:
	return actor.is_placing or actor.selectable.is_selected


func _is_valid() -> bool:
	return not actor.is_placing or actor.is_valid_placement


func _draw() -> void:
	drawn_state = Vector3(float(_is_shown()), float(_is_valid()), actor.radius)
	if not draw_range or not _is_shown():
		return
	var color : Color = RING_COLOR if _is_valid() else INVALID_RING_COLOR
	var min_radius : float = _get_min_radius()
	if min_radius <= 0.0:
		draw_circle(Vector2.ZERO, actor.radius, Color(color, FILL_ALPHA), true, -1.0, false)
	else:
		#a band: the Mortar's dead zone around it stays clear, with a faint inner ring
		var band : float = actor.radius - min_radius
		draw_arc(Vector2.ZERO, min_radius + band * 0.5, 0.0, TAU, RING_POINTS, Color(color, FILL_ALPHA), band, false)
		draw_arc(Vector2.ZERO, min_radius, 0.0, TAU, RING_POINTS, Color(color, RING_ALPHA * 0.5), 1.0, false)
	draw_arc(Vector2.ZERO, actor.radius, 0.0, TAU, RING_POINTS, Color(color, RING_ALPHA), 1.0, false)


func _get_min_radius() -> float:
	if not actor is Tower:
		return 0.0
	return minf((actor as Tower).min_range_tiles * Utils.TILE_SIZE, actor.radius)
