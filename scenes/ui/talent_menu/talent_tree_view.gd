class_name TalentTreeView
extends Control

## Draws one talent tree: its shape, the links and the nodes. Click a node to select it, drag to
## pan, and the wheel zooms in whole steps so the pixels stay whole.

signal node_selected(node : TalentNode)

## Screen pixels per tree unit at each zoom step. The selected node and the one under the mouse are
## always named, learned nodes from the second step, so the names never pile up.
const UNIT_SIZES : Array[int] = [13, 26, 40]
const LEARNED_LABEL_ZOOM : int = 1
const NODE_SIZES : Array[int] = [7, 11, 15]
const FONT_SIZE : int = 8
const DRAG_THRESHOLD : float = 3.0
const PICK_RADIUS : float = 9.0
const FIT_MARGIN : float = 1.5

#what the player has not learned stays dark, so the learned path stands out; the shape's colours come from the tree
#unlearned colours are the tree's own lit colour, darkened
const LINK_HALF_DARKEN : float = 0.6
const NODE_OPEN_DARKEN : float = 0.68
#with points to spend, a node that can be learned now is brighter than the other open ones, so the next options stand out
const NODE_PICKABLE_DARKEN : float = 0.35
const LINK_LOCKED_DARKEN : float = 0.35
const NODE_LOCKED_DARKEN : float = 0.1
#a learned node below its max rank is a little dimmer than its full colour
const PARTIAL_DIM : float = 0.3
const MAXED_GLOW : Color = Color("fff6c8")
const NODE_EDGE : Color = Color("0a1612")
const SELECTED_EDGE : Color = Color("f2c14e")
const NOT_BUILT_MARK : Color = Color("86b8a0")
const TEXT : Color = Color("c9f2dc")
const TEXT_OUTLINE : Color = Color("0a1612")

var tree : TalentTree = null
var ranks : Dictionary = {}
var unspent_points : int = 0
var selected_id : StringName = &""
var hovered_id : StringName = &""
var zoom_index : int = 0
#screen position of the tree's origin
var origin : Vector2 = Vector2.ZERO
var _press_position : Vector2 = Vector2.ZERO
var _is_pressed : bool = false
var _is_dragging : bool = false


func _ready() -> void:
	clip_contents = true
	resized.connect(fit_tree)


func show_tree(new_tree : TalentTree) -> void:
	tree = new_tree
	selected_id = tree.start_id
	fit_tree()


func refresh(new_ranks : Dictionary, new_unspent_points : int) -> void:
	ranks = new_ranks
	unspent_points = new_unspent_points
	queue_redraw()


## The smallest zoom step, centred on the tree.
func fit_tree() -> void:
	if tree == null:
		return

	zoom_index = 0
	origin = (size / 2.0 - _get_bounds().get_center() * UNIT_SIZES[zoom_index]).round()
	queue_redraw()


func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _is_pressed and not _is_dragging and event.position.distance_to(_press_position) > DRAG_THRESHOLD:
			_is_dragging = true
		if _is_dragging:
			origin += event.relative
			queue_redraw()
			return
		var hovered : TalentNode = _get_node_at(event.position)
		var new_hovered_id : StringName = hovered.id if hovered != null else &""
		if new_hovered_id != hovered_id:
			hovered_id = new_hovered_id
			queue_redraw()


func _on_mouse_button(event : InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(1, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(-1, event.position)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_pressed = true
				_is_dragging = false
				_press_position = event.position
				return

			_is_pressed = false
			if not _is_dragging and event.button_index == MOUSE_BUTTON_LEFT:
				_pick(event.position)
			_is_dragging = false

	accept_event()


#keeps the tree point under the mouse in place
func _zoom(step : int, at : Vector2) -> void:
	var new_index : int = clampi(zoom_index + step, 0, UNIT_SIZES.size() - 1)

	if new_index == zoom_index:
		return

	var tree_point : Vector2 = (at - origin) / UNIT_SIZES[zoom_index]
	zoom_index = new_index
	origin = (at - tree_point * UNIT_SIZES[zoom_index]).round()
	queue_redraw()


func _pick(at : Vector2) -> void:
	var picked : TalentNode = _get_node_at(at)

	if picked == null:
		return

	selected_id = picked.id
	node_selected.emit(picked)
	queue_redraw()


func _get_node_at(at : Vector2) -> TalentNode:
	if tree == null:
		return null

	var nearest : TalentNode = null
	var nearest_distance : float = PICK_RADIUS + NODE_SIZES[zoom_index] / 2.0

	for node in tree.nodes:
		var distance : float = at.distance_to(_to_screen(node.position))
		if distance < nearest_distance:
			nearest = node
			nearest_distance = distance

	return nearest


func _draw() -> void:
	if tree == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), tree.background)

	for shape in tree.shapes:
		var points : PackedVector2Array = _shape_to_screen(shape)
		draw_colored_polygon(points, tree.shape_fill)
		points.append(points[0])
		draw_polyline(points, tree.shape_edge, 1.0)

	for line in tree.lines:
		draw_polyline(_shape_to_screen(line), tree.shape_edge, 1.0)

	for node in tree.nodes:
		for linked_id in node.links:
			_draw_link(node, tree.get_node_by_id(linked_id), false)
		for target_id in node.one_way_links:
			_draw_link(node, tree.get_node_by_id(target_id), true)

	for node in tree.nodes:
		_draw_node(node)

	for node in tree.nodes:
		var is_learned_label : bool = zoom_index >= LEARNED_LABEL_ZOOM and TalentRules.get_rank(ranks, node.id) > 0
		if is_learned_label or node.id == selected_id or node.id == hovered_id:
			_draw_label(node)


func _draw_link(from : TalentNode, to : TalentNode, is_one_way : bool) -> void:
	if to == null:
		return

	var from_rank : int = TalentRules.get_rank(ranks, from.id)
	var to_rank : int = TalentRules.get_rank(ranks, to.id)
	var color : Color = tree.link_lit if from_rank > 0 and to_rank > 0 else tree.link_lit.darkened(LINK_HALF_DARKEN) if from_rank > 0 or to_rank > 0 else tree.shape_edge.darkened(LINK_LOCKED_DARKEN)
	var width : float = 2.0 if zoom_index > 0 else 1.0

	if is_one_way:
		draw_dashed_line(_to_screen(from.position), _to_screen(to.position), color, width, 3.0)
	else:
		draw_line(_to_screen(from.position), _to_screen(to.position), color, width)


func _draw_node(node : TalentNode) -> void:
	var center : Vector2 = _to_screen(node.position)
	var node_size : float = NODE_SIZES[zoom_index] + (2 if node.kind == TalentNode.Kind.Capstone else 0) - (2 if node.kind == TalentNode.Kind.Side else 0)
	var half : float = floorf(node_size / 2.0)
	var rank : int = TalentRules.get_rank(ranks, node.id)
	var is_maxed : bool = rank >= node.max_rank
	var fill : Color = tree.shape_fill.darkened(NODE_LOCKED_DARKEN)
	if rank > 0:
		fill = node.color.lightened(0.15) if is_maxed else node.color.darkened(PARTIAL_DIM)
	elif TalentRules.can_add(tree, ranks, node, unspent_points):
		fill = tree.link_lit.darkened(NODE_PICKABLE_DARKEN)
	elif TalentRules.is_open(tree, ranks, node):
		fill = tree.link_lit.darkened(NODE_OPEN_DARKEN)
	var edge : Color = SELECTED_EDGE if node.id == selected_id else MAXED_GLOW if is_maxed else NODE_EDGE

	#a maxed node shines: a light ring around it
	if is_maxed and rank > 0:
		var glow : Rect2 = Rect2(center - Vector2(half + 2, half + 2), Vector2(half * 2 + 5, half * 2 + 5))
		draw_rect(glow, Color(MAXED_GLOW, 0.35))

	if node.kind == TalentNode.Kind.Evolve:
		var diamond : PackedVector2Array = [center + Vector2(0, -half - 1), center + Vector2(half + 1, 0), center + Vector2(0, half + 1), center + Vector2(-half - 1, 0)]
		draw_colored_polygon(diamond, fill)
		diamond.append(diamond[0])
		draw_polyline(diamond, edge, 1.0)
	else:
		var rect : Rect2 = Rect2(center - Vector2(half, half), Vector2(half * 2 + 1, half * 2 + 1))
		draw_rect(rect, fill)
		draw_rect(rect, edge, false, 1.0)
		if node.kind == TalentNode.Kind.Capstone:
			draw_rect(rect.grow(-2), edge, false, 1.0)

	if not node.is_implemented:
		draw_rect(Rect2(center + Vector2(half - 1, -half - 2), Vector2(3, 3)), NOT_BUILT_MARK)

	if zoom_index > 0 and rank > 0:
		_draw_text(str(rank), center + Vector2(0, 3), NODE_EDGE, false)


func _draw_label(node : TalentNode) -> void:
	var half : float = NODE_SIZES[zoom_index] / 2.0
	_draw_text(node.display_name, _to_screen(node.position) + Vector2(0, half + FONT_SIZE + 1), TEXT, true)


func _draw_text(text : String, at : Vector2, color : Color, outlined : bool) -> void:
	var font : Font = get_theme_default_font()
	var width : float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var text_position : Vector2 = (at - Vector2(width / 2.0, 0)).round()

	if outlined:
		draw_string_outline(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, TEXT_OUTLINE)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _to_screen(tree_position : Vector2) -> Vector2:
	return (origin + tree_position * UNIT_SIZES[zoom_index]).round()


func _shape_to_screen(shape : PackedVector2Array) -> PackedVector2Array:
	var points : PackedVector2Array = []
	for point in shape:
		points.append(_to_screen(point))
	return points


func _get_bounds() -> Rect2:
	var bounds : Rect2 = Rect2(tree.nodes[0].position, Vector2.ZERO)

	for node in tree.nodes:
		bounds = bounds.expand(node.position)
	for shape in tree.shapes:
		for point in shape:
			bounds = bounds.expand(point)

	return bounds.grow(FIT_MARGIN)
