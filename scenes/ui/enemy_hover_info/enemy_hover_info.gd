class_name EnemyHoverInfo
extends Node2D

## A small parchment card by the cursor with the name and health of the enemy under it, so a
## look does not need a click (the selection card still has the details). Waits HOVER_DELAY
## seconds on one enemy; hidden over the UI, while placing a building and for the selected
## enemy. Screen space, like the damage numbers, so the camera zoom never stretches its font.
## Created by Level. Runs while paused only to hide itself, so a pause menu never has a stale card over it.

const NODE_NAME : String = "EnemyHoverInfo"
## How far from the cursor an enemy counts as under it, in world pixels.
const HOVER_RADIUS : float = 10.0
const HOVER_DELAY : float = 0.2
## GameCursor shows the target ring over an enemy (at once, before the card's delay).
const CURSOR_SOURCE : StringName = &"enemy_hover"
## Screen pixels from the cursor to the card's corner.
const CURSOR_OFFSET : Vector2 = Vector2(10, 10)
const PANEL_THEME_TYPE : StringName = &"TooltipPanel"
#the UI's layer (Main's UI CanvasLayer is layer 1); the card hides itself whenever a menu pauses the game
const LAYER : int = 1
const HEALTH_FORMAT : String = "Health %d / %d"
const FLYING_TEXT : String = "Flying"
const ELITE_TEXT : String = "Elite"
const BOSS_TEXT : String = "Boss"
const TAG_SEPARATOR : String = ", "

var hovered : Enemy = null
var is_targeting : bool = false
var hover_time : float = 0.0
var shown_text : String = ""
var is_cursor_on_gui : bool = false
var is_placing_building : bool = false

var layer : CanvasLayer = null
var panel : PanelContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = LAYER
	add_child(layer)
	panel = PanelContainer.new()
	panel.theme_type_variation = PANEL_THEME_TYPE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	layer.add_child(panel)
	UISignals.mouse_on_gui.connect(_on_mouse_on_gui)
	GameSignals.building_placement_change.connect(_on_building_placement_change)


func _process(delta : float) -> void:
	var enemy : Enemy = null
	if not is_cursor_on_gui and not is_placing_building and not get_tree().paused:
		enemy = find_enemy_at(get_global_mouse_position())
	#on its own flag: a hovered enemy that died compares equal to null, so the change would be missed
	if (enemy != null) != is_targeting:
		is_targeting = enemy != null
		UISignals.cursor_mode_requested.emit(CURSOR_SOURCE, GameCursor.Mode.TARGET if is_targeting else GameCursor.Mode.POINTER)
	if enemy != hovered:
		hovered = enemy
		hover_time = 0.0
	if hovered == null or (hovered.selectable != null and hovered.selectable.is_selected):
		_hide()
		return
	hover_time += delta
	if hover_time < HOVER_DELAY:
		_hide()
		return
	_show(build_text(hovered))


## The nearest enemy that can be seen within HOVER_RADIUS of the world point, or null.
func find_enemy_at(world_point : Vector2) -> Enemy:
	var nearest : Enemy = null
	var nearest_distance : float = HOVER_RADIUS * HOVER_RADIUS
	for node in get_tree().get_nodes_in_group(GroupNames.ENEMIES):
		var enemy : Enemy = node as Enemy
		if enemy == null or not _is_visible(enemy):
			continue
		var distance : float = enemy.global_position.distance_squared_to(world_point)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


## The card's text: the name as the selection card shows it, then health and tags.
static func build_text(enemy : Enemy) -> String:
	var title : String = enemy.selectable.get_display_name() if enemy.selectable != null else String(enemy.name)
	var health : float = maxf(0.0, enemy.stats.get_stat_value(Utils.StatType.Health))
	var max_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
	var lines : PackedStringArray = [title, HEALTH_FORMAT % [ceili(health), ceili(max_health)]]
	var tags : PackedStringArray = []
	if enemy.is_boss:
		tags.append(BOSS_TEXT)
	if enemy.get_node_or_null(NodePath(Elite.NAME)) != null:
		tags.append(ELITE_TEXT)
	if enemy.is_flying:
		tags.append(FLYING_TEXT)
	if not tags.is_empty():
		lines.append(TAG_SEPARATOR.join(tags))
	return "\n".join(lines)


func _is_visible(enemy : Enemy) -> bool:
	return not enemy.is_dead and not enemy.is_deactivated and not enemy.is_burrowed \
			and not enemy.is_concealed and enemy.visible


func _show(text : String) -> void:
	if text != shown_text:
		shown_text = text
		#out of the panel at once, so reset_size() measures the new text, not the old one still waiting to be freed
		for child in panel.get_children():
			panel.remove_child(child)
			child.queue_free()
		var label : Control = RichTooltip.build(text)
		if label != null:
			panel.add_child(label)
		panel.reset_size()
	panel.visible = true
	_place_panel()


func _place_panel() -> void:
	var view_size : Vector2 = get_viewport().get_visible_rect().size
	var corner : Vector2 = get_viewport().get_mouse_position() + CURSOR_OFFSET
	var size : Vector2 = panel.get_combined_minimum_size()
	#flipped to the cursor's other side near the window's right or bottom edge
	if corner.x + size.x > view_size.x:
		corner.x -= size.x + CURSOR_OFFSET.x * 2.0
	if corner.y + size.y > view_size.y:
		corner.y -= size.y + CURSOR_OFFSET.y * 2.0
	panel.position = corner.round()


func _hide() -> void:
	panel.visible = false


func _on_mouse_on_gui(value : bool) -> void:
	is_cursor_on_gui = value


func _on_building_placement_change(is_placing : bool) -> void:
	is_placing_building = is_placing


func _exit_tree() -> void:
	if is_targeting:
		is_targeting = false
		UISignals.cursor_mode_requested.emit(CURSOR_SOURCE, GameCursor.Mode.POINTER)
