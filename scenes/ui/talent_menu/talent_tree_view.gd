@tool
class_name TalentTreeView
extends Control

## Draws one talent tree: the links and the nodes. Click a node to select it, drag to pan, and the
## wheel zooms in whole steps so the pixels stay whole. In edit mode (the editor's Talents screen)
## dragging a node moves it instead, and the links follow.

signal node_selected(node : TalentNode)
## Edit mode: a node was dropped somewhere else.
signal node_moved(node : TalentNode, from_position : Vector2)

## Screen pixels per tree unit at each zoom step. The selected node and the one under the mouse are
## always named, learned nodes from the second step, so the names never pile up.
const UNIT_SIZES : Array[int] = [13, 26, 40]
const LEARNED_LABEL_ZOOM : int = 1
const NODE_SIZES : Array[int] = [9, 11, 15]
const FONT_SIZE : int = 8
const DRAG_THRESHOLD : float = 3.0
const PICK_RADIUS : float = 9.0
const FIT_MARGIN : float = 1.5
## Panning and zooming keep at least this many screen pixels of the tree inside the view (less in a
## smaller view), so the tree can never be dragged out of sight and lost.
const KEEP_IN_VIEW : float = 64.0

#what the player has not learned stays dim, so the learned path stands out; the shape's colours come from the tree
#unlearned links are the tree's own lit colour, darkened
const LINK_HALF_DARKEN : float = 0.3
#locked links still come from the lit colour, so they read brighter than the shape's outline lines
const LINK_LOCKED_DARKEN : float = 0.5
#a dark line under every link keeps it apart from the shape fill (from the second zoom step, the lines are too close before)
const LINK_BACKING_EXTRA : float = 2.0
#unlearned nodes keep their route's colour, dimmed, so the routes read before anything is learned
const NODE_LOCKED_DARKEN : float = 0.72
const NODE_LOCKED_EDGE_DARKEN : float = 0.45
const NODE_OPEN_DARKEN : float = 0.45
#with points to spend, a node that can be learned now is almost full colour and pulses, so the next options stand out
const NODE_PICKABLE_DARKEN : float = 0.1
#a learned node below its max rank is a little dimmer than its full colour
const PARTIAL_DIM : float = 0.3
#the pulse steps through a few whole alphas instead of fading smoothly, like the rest of the pixel art
const PULSE_STEPS : Array[float] = [0.0, 0.25, 0.5, 0.25]
const PULSE_STEP_TIME_MSEC : int = 160
const MAXED_GLOW : Color = Color("fff6c8")
const NODE_EDGE : Color = Color("0a1612")
const SELECTED_EDGE : Color = Color("f2c14e")
const HOVER_EDGE : Color = Color("c9f2dc")
const NOT_BUILT_DARKEN : float = 0.35
const TEXT : Color = Color("c9f2dc")
const TEXT_OUTLINE : Color = Color("0a1612")
const HINT_COLOR : Color = Color("86b8a0")
const HINT_MARGIN : Vector2 = Vector2(4, 4)
const HINT_LEARN_TEXT : String = "Click a glowing talent to learn it"
const HINT_EARN_TEXT : String = "Clear levels to earn talent points"
const HINT_MOVE_TEXT : String = "Drag to move, wheel to zoom"
const HINT_EDIT_TEXT : String = "Drag a node to move it, drag elsewhere to pan, wheel to zoom"
#node positions keep three decimals, like the generated trees
const EDIT_SNAP : float = 0.001
## Node art (polish, 2026-11-22): a bevel on the square nodes, the effect's icon inside (when the node is big enough),
## rank pips under a node with more than one rank from zoom 1, and the tree's element as a faint emblem behind it all.
const BEVEL_LIGHTEN : float = 0.3
const BEVEL_DARKEN : float = 0.4
const ICON_SIZE : int = 7
const ICON_LOCKED : Color = Color(0.7, 0.7, 0.7, 0.9)
const ICON_OPEN : Color = Color(0.9, 0.9, 0.9)
const PIP_SIZE : Vector2 = Vector2(2, 2)
const PIP_SPACING : float = 3.0
const PIP_GAP : float = 2.0
## Room the pips take under a node; labels sit below it.
const PIP_ROOM : float = 4.0
const PIP_EMPTY : Color = Color("26332e")
const EMBLEM_SCALE : int = 8
const EMBLEM_ALPHA : float = 0.06
const EMBLEMS : Dictionary[Utils.Element, Texture2D] = {
	Utils.Element.Fire: preload("res://assets/art/ui/fire_element_icon.png"),
	Utils.Element.Frost: preload("res://assets/art/ui/frost_element_icon.png"),
	Utils.Element.Poison: preload("res://assets/art/ui/poison_element_icon.png"),
}
## The Building tree has no element: its emblem is the wall.
const BUILDING_EMBLEM : Texture2D = preload("res://assets/art/ui/stat_icons/stat_wall.png")
## Edit mode: nodes can be dragged; the player's ranks are not drawn.
@export var edit_mode : bool = false
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
var _pulse_step : int = 0
#edit mode: the node under the press, moved while dragging
var _moving_node : TalentNode = null
var _moving_from : Vector2 = Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	resized.connect(fit_tree)
	set_process(false)


#only runs while some node can be learned, to step its pulse
func _process(_delta : float) -> void:
	var step : int = floori(Time.get_ticks_msec() / float(PULSE_STEP_TIME_MSEC)) % PULSE_STEPS.size()

	if step != _pulse_step:
		_pulse_step = step
		queue_redraw()


func show_tree(new_tree : TalentTree) -> void:
	tree = new_tree
	selected_id = tree.start_id
	fit_tree()


func refresh(new_ranks : Dictionary, new_unspent_points : int) -> void:
	ranks = new_ranks
	unspent_points = new_unspent_points
	set_process(_has_pickable_node())
	queue_redraw()


func _has_pickable_node() -> bool:
	if tree == null or unspent_points <= 0:
		return false

	for node in tree.nodes:
		if TalentRules.can_add(tree, ranks, node, unspent_points):
			return true

	return false


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
		if _is_dragging and _moving_node != null:
			_moving_node.position = _to_tree(event.position)
			queue_redraw()
			return
		if _is_dragging:
			origin = _clamp_origin(origin + event.relative)
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
				_moving_node = _get_node_at(event.position) if edit_mode and event.button_index == MOUSE_BUTTON_LEFT else null
				if _moving_node != null:
					_moving_from = _moving_node.position
				accept_event()
				return

			_is_pressed = false
			if _moving_node != null:
				var moved : TalentNode = _moving_node
				_moving_node = null
				if _is_dragging and moved.position != _moving_from:
					node_moved.emit(moved, _moving_from)
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
	origin = _clamp_origin((at - tree_point * UNIT_SIZES[zoom_index]).round())
	queue_redraw()


## The origin moved back just enough that KEEP_IN_VIEW pixels of the tree's bounds stay on screen on each axis.
func _clamp_origin(wanted : Vector2) -> Vector2:
	if tree == null or tree.nodes.is_empty():
		return wanted
	var bounds : Rect2 = _get_bounds()
	var unit : float = UNIT_SIZES[zoom_index]
	var keep : Vector2 = Vector2(minf(KEEP_IN_VIEW, size.x / 2.0), minf(KEEP_IN_VIEW, size.y / 2.0))
	#the tree's screen rect is origin + bounds * unit: its far edge must reach keep, its near edge stay keep short of the far side
	var lowest : Vector2 = keep - bounds.end * unit
	var highest : Vector2 = size - keep - bounds.position * unit
	return Vector2(clampf(wanted.x, lowest.x, highest.x), clampf(wanted.y, lowest.y, highest.y)).round()


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
	_draw_emblem()

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

	_draw_hint()


#fixed on the screen, so it stays behind the tree whatever the pan and zoom; whole-step scaled
func _draw_emblem() -> void:
	var emblem : Texture2D = EMBLEMS.get(tree.element, BUILDING_EMBLEM)
	var emblem_size : Vector2 = emblem.get_size() * EMBLEM_SCALE * (2 if emblem == BUILDING_EMBLEM else 1)
	var at : Vector2 = ((size - emblem_size) / 2.0).round()
	draw_texture_rect(emblem, Rect2(at, emblem_size), false, Color(1, 1, 1, EMBLEM_ALPHA))


#one line in the corner tells a new player what to do here
func _draw_hint() -> void:
	var font : Font = get_theme_default_font()
	var hint : String = HINT_LEARN_TEXT if is_processing() else HINT_EARN_TEXT if unspent_points <= 0 else ""
	if edit_mode:
		hint = ""
	#top left: the tree's root sits at the bottom, so the corner above it stays free
	var line : Vector2 = HINT_MARGIN + Vector2(0, FONT_SIZE)

	for text in [hint, HINT_EDIT_TEXT if edit_mode else HINT_MOVE_TEXT]:
		if text.is_empty():
			continue
		draw_string_outline(font, line, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, TEXT_OUTLINE)
		draw_string(font, line, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, HINT_COLOR)
		line.y += FONT_SIZE + 2


func _draw_link(from : TalentNode, to : TalentNode, is_one_way : bool) -> void:
	if to == null:
		return

	var from_rank : int = TalentRules.get_rank(ranks, from.id)
	var to_rank : int = TalentRules.get_rank(ranks, to.id)
	var color : Color = tree.link_lit if from_rank > 0 and to_rank > 0 else tree.link_lit.darkened(LINK_HALF_DARKEN) if from_rank > 0 or to_rank > 0 else tree.link_lit.darkened(LINK_LOCKED_DARKEN)
	#-1 is Godot's always-one-pixel line: a 1.0 wide polygon line collapses under the pixel snapping
	var width : float = 2.0 if zoom_index > 0 else -1.0
	var start : Vector2 = _to_screen(from.position)
	var end : Vector2 = _to_screen(to.position)

	if zoom_index > 0:
		draw_line(start, end, NODE_EDGE, width + LINK_BACKING_EXTRA)
	if is_one_way:
		draw_dashed_line(start, end, color, width, 3.0)
	else:
		draw_line(start, end, color, width)


func _draw_node(node : TalentNode) -> void:
	var center : Vector2 = _to_screen(node.position)
	var node_size : float = NODE_SIZES[zoom_index] + (2 if node.kind == TalentNode.Kind.Capstone else 0) - (2 if node.kind == TalentNode.Kind.Side else 0)
	var half : float = floorf(node_size / 2.0)
	var rank : int = TalentRules.get_rank(ranks, node.id)
	var is_maxed : bool = rank >= node.max_rank
	var is_pickable : bool = rank < node.max_rank and TalentRules.can_add(tree, ranks, node, unspent_points)
	var fill : Color = node.color.darkened(NODE_LOCKED_DARKEN)
	var edge : Color = node.color.darkened(NODE_LOCKED_EDGE_DARKEN)
	if rank > 0:
		fill = node.color.lightened(0.15) if is_maxed else node.color.darkened(PARTIAL_DIM)
		edge = MAXED_GLOW if is_maxed else NODE_EDGE
	elif is_pickable:
		fill = node.color.darkened(NODE_PICKABLE_DARKEN)
		edge = NODE_EDGE
	elif TalentRules.is_open(tree, ranks, node):
		fill = node.color.darkened(NODE_OPEN_DARKEN)
		edge = NODE_EDGE
	if node.id == selected_id:
		edge = SELECTED_EDGE
	elif node.id == hovered_id:
		edge = HOVER_EDGE

	#a maxed node shines: a light ring around it
	if is_maxed and rank > 0:
		var glow : Rect2 = Rect2(center - Vector2(half + 2, half + 2), Vector2(half * 2 + 5, half * 2 + 5))
		draw_rect(glow, Color(MAXED_GLOW, 0.35))
	#a node that can be learned now pulses in its own colour
	elif is_pickable:
		var pulse : Rect2 = Rect2(center - Vector2(half + 3, half + 3), Vector2(half * 2 + 7, half * 2 + 7))
		draw_rect(pulse, Color(node.color, PULSE_STEPS[_pulse_step]))

	if node.kind == TalentNode.Kind.Evolve:
		var diamond : PackedVector2Array = [center + Vector2(0, -half - 1), center + Vector2(half + 1, 0), center + Vector2(0, half + 1), center + Vector2(-half - 1, 0)]
		draw_colored_polygon(diamond, fill)
		diamond.append(diamond[0])
		draw_polyline(diamond, edge, 1.0)
	else:
		var rect : Rect2 = Rect2(center - Vector2(half, half), Vector2(half * 2 + 1, half * 2 + 1))
		draw_rect(rect, fill)
		_draw_bevel(rect, fill)
		draw_rect(rect, edge, false, 1.0)
		if node.kind == TalentNode.Kind.Capstone:
			draw_rect(rect.grow(-2), edge, false, 1.0)

	#a quiet corner dot: the info window says the rest
	if not node.is_implemented and zoom_index > 0:
		draw_rect(Rect2(center + Vector2(half, -half - 1), Vector2(2, 2)), HINT_COLOR.darkened(NOT_BUILT_DARKEN))

	#any zoom where the icon fits inside the frame (the default whole-tree view too)
	if node_size >= ICON_SIZE + 2:
		var icon : Texture2D = TalentNodeIcons.for_node(node)
		if icon != null:
			var tint : Color = Color.WHITE if rank > 0 or is_pickable else ICON_OPEN if TalentRules.is_open(tree, ranks, node) else ICON_LOCKED
			draw_texture(icon, center - Vector2(ICON_SIZE / 2, ICON_SIZE / 2), tint)
	if zoom_index > 0 and node.max_rank > 1 and (rank > 0 or is_pickable):
		_draw_pips(center + Vector2(0, half + PIP_GAP + 1), rank, node.max_rank)


#light along the top and left inside the frame, shade along the bottom and right: a raised gem
func _draw_bevel(rect : Rect2, fill : Color) -> void:
	var inner : Rect2 = rect.grow(-1)
	if inner.size.x < 3.0:
		return
	var light : Color = fill.lightened(BEVEL_LIGHTEN)
	var shade : Color = fill.darkened(BEVEL_DARKEN)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), light)
	draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), light)
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - 1), Vector2(inner.size.x, 1)), shade)
	draw_rect(Rect2(Vector2(inner.end.x - 1, inner.position.y), Vector2(1, inner.size.y)), shade)


#one pip per rank under the node, lit in the tree's accent up to the rank
func _draw_pips(top_center : Vector2, rank : int, max_rank : int) -> void:
	var width : float = (max_rank - 1) * PIP_SPACING + PIP_SIZE.x
	var left : float = roundf(top_center.x - width / 2.0)
	for i in max_rank:
		draw_rect(Rect2(Vector2(left + i * PIP_SPACING, top_center.y), PIP_SIZE), tree.accent if i < rank else PIP_EMPTY)


func _draw_label(node : TalentNode) -> void:
	var half : float = NODE_SIZES[zoom_index] / 2.0
	var pip_room : float = PIP_ROOM if zoom_index > 0 and node.max_rank > 1 else 0.0
	_draw_text(node.display_name, _to_screen(node.position) + Vector2(0, half + FONT_SIZE + 1 + pip_room), TEXT, true)


func _draw_text(text : String, at : Vector2, color : Color, outlined : bool) -> void:
	var font : Font = get_theme_default_font()
	var width : float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var text_position : Vector2 = (at - Vector2(width / 2.0, 0)).round()

	if outlined:
		draw_string_outline(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, TEXT_OUTLINE)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _to_screen(tree_position : Vector2) -> Vector2:
	return (origin + tree_position * UNIT_SIZES[zoom_index]).round()


#whole screen pixels at the current zoom, so a dropped node sits where it was drawn
func _to_tree(screen_position : Vector2) -> Vector2:
	var tree_position : Vector2 = (screen_position.round() - origin) / UNIT_SIZES[zoom_index]
	return Vector2(snappedf(tree_position.x, EDIT_SNAP), snappedf(tree_position.y, EDIT_SNAP))


func _get_bounds() -> Rect2:
	var bounds : Rect2 = Rect2(tree.nodes[0].position, Vector2.ZERO)

	for node in tree.nodes:
		bounds = bounds.expand(node.position)

	return bounds.grow(FIT_MARGIN)
