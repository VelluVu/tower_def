class_name MapTrails
extends Control

## The dotted trails between the world map's level nodes (2026-11-24): one from each shown level to the next, in the
## colour of the area it leads into. A newly unlocked stretch draws itself in dot by dot (reveal). Sits under the
## nodes in the Map; only looks.

signal revealed

## Dot fill per area (MapLevelElement.area_of): Caves, Swamp, Wasted Lands, Ash Desert, Volcano.
const AREA_COLORS : Array[Color] = [Color("ead4aa"), Color("63c74d"), Color("feae34"), Color("f77622"), Color("ffffff")]
const OUTLINE_COLOR : Color = Color("3e2731")
## Map units (2 per art pixel): the dot's fill, its outline ring, the gap between dots, the room left round a node.
const DOT_SIZE : float = 4.0
const OUTLINE_WIDTH : float = 2.0
const DOT_SPACING : float = 12.0
const NODE_CLEARANCE : float = 14.0
## How far a trail bows out from the straight line, as a share of its length (each trail its own way, steady).
const BEND : float = 0.16
const REVEAL_SECONDS : float = 0.9
## Corner cutting passes over a trail with waypoints, so it bends round them smoothly.
const SMOOTHING_PASSES : int = 3

var elements : Dictionary[int, MapLevelElement] = {}
#the level whose trail is drawing in, and how far it has got (0..1)
var revealing_level : int = 0
var reveal_progress : float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_parent().get_children():
		var element : MapLevelElement = child as MapLevelElement
		if element != null:
			elements[element.level_number] = element


## Draws the trail into `level` in, dot by dot; emits revealed when done (at once when it has no trail).
func reveal(level : int) -> void:
	if not elements.has(level) or not elements.has(level - 1):
		revealed.emit.call_deferred()
		return
	revealing_level = level
	reveal_progress = 0.0
	var tween : Tween = create_tween()
	tween.tween_method(_set_reveal_progress, 0.0, 1.0, REVEAL_SECONDS)
	tween.tween_callback(func() -> void: revealed.emit())


func _set_reveal_progress(value : float) -> void:
	reveal_progress = value
	queue_redraw()


func _draw() -> void:
	for level in elements:
		var element : MapLevelElement = elements[level]
		var previous : MapLevelElement = elements.get(level - 1)
		if previous == null or not element.visible or not previous.visible:
			continue
		var share : float = reveal_progress if level == revealing_level else 1.0
		_draw_trail(_centre(previous), _centre(element), element.trail_via, AREA_COLORS[MapLevelElement.area_of(level)], share, level)


## The path of the trail into `level` (from the previous level's node to this one's), in map units; empty when it has
## none. MapFog clears the fog along it.
func trail_points(level : int) -> PackedVector2Array:
	var element : MapLevelElement = elements.get(level)
	var previous : MapLevelElement = elements.get(level - 1)
	if element == null or previous == null:
		return PackedVector2Array()
	var from : Vector2 = _centre(previous)
	var to : Vector2 = _centre(element)
	return _bowed(from, to, level) if element.trail_via.is_empty() else _through(from, element.trail_via, to)


func _centre(element : MapLevelElement) -> Vector2:
	return element.position + element.size * 0.5


func _draw_trail(from : Vector2, to : Vector2, via : PackedVector2Array, fill : Color, share : float, level : int) -> void:
	var length : float = from.distance_to(to)
	if length <= NODE_CLEARANCE * 2.0:
		return
	var points : PackedVector2Array = _bowed(from, to, level) if via.is_empty() else _through(from, via, to)
	var travelled : float = 0.0
	var next_dot : float = NODE_CLEARANCE
	var total : float = _polyline_length(points)
	var last : float = minf(total - NODE_CLEARANCE, NODE_CLEARANCE + (total - NODE_CLEARANCE * 2.0) * share)
	for i in range(1, points.size()):
		var segment : float = points[i - 1].distance_to(points[i])
		while next_dot <= travelled + segment and next_dot <= last:
			var at : Vector2 = points[i - 1].lerp(points[i], (next_dot - travelled) / maxf(segment, 0.001))
			_draw_dot(at, fill)
			next_dot += DOT_SPACING
		travelled += segment


#a gentle bow to one side, each trail its own way; a fine polyline so the dots can be spaced along it
func _bowed(from : Vector2, to : Vector2, level : int) -> PackedVector2Array:
	var length : float = from.distance_to(to)
	var side : float = 1.0 if level % 2 == 0 else -1.0
	var control : Vector2 = (from + to) * 0.5 + (to - from).orthogonal().normalized() * length * BEND * side
	var points : PackedVector2Array = PackedVector2Array()
	var steps : int = maxi(8, int(length / 2.0))
	for i in steps + 1:
		var t : float = float(i) / steps
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	return points


#through the waypoints, corners cut (Chaikin) so it curves; the ends stay on the nodes
func _through(from : Vector2, via : PackedVector2Array, to : Vector2) -> PackedVector2Array:
	var points : PackedVector2Array = PackedVector2Array([from])
	points.append_array(via)
	points.append(to)
	for pass_index in SMOOTHING_PASSES:
		var smoothed : PackedVector2Array = PackedVector2Array([points[0]])
		for i in points.size() - 1:
			smoothed.append(points[i].lerp(points[i + 1], 0.25))
			smoothed.append(points[i].lerp(points[i + 1], 0.75))
		smoothed.append(points[points.size() - 1])
		points = smoothed
	return points


func _polyline_length(points : PackedVector2Array) -> float:
	var total : float = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


#on whole art pixels (2 map units), so the dots sit on the map's pixel grid
func _draw_dot(at : Vector2, fill : Color) -> void:
	var corner : Vector2 = (at / 2.0).floor() * 2.0 - Vector2.ONE * DOT_SIZE * 0.5
	draw_rect(Rect2(corner - Vector2.ONE * OUTLINE_WIDTH, Vector2.ONE * (DOT_SIZE + OUTLINE_WIDTH * 2.0)), OUTLINE_COLOR)
	draw_rect(Rect2(corner, Vector2.ONE * DOT_SIZE), fill)
