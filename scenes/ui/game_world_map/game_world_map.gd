class_name GameWorldMap
extends Control


const TALENTS_TEXT : String = "Talents"
const TALENTS_WITH_POINTS_TEXT : String = "Talents (%d)"
## The map is bigger than the screen (2026-11-24): it scrolls by keys, the wheel (Shift for sideways) and dragging
## empty ground with the left or middle button.
const KEY_SCROLL_SPEED : float = 260.0
const WHEEL_STEP : float = 36.0
const DRAG_THRESHOLD : float = 4.0
const MOVE_LEFT_ACTION : String = "MoveCameraLeft"
const MOVE_RIGHT_ACTION : String = "MoveCameraRight"
const MOVE_UP_ACTION : String = "MoveCameraUp"
const MOVE_DOWN_ACTION : String = "MoveCameraDown"
## GameCursor shows the grabbing claw while the map is dragged.
const CURSOR_SOURCE : StringName = &"map_drag"

@onready var to_menu_button : Button = $ToMenuButton
@onready var talents_button : Button = $TalentsButton
@onready var map_view : Control = $MapView
@onready var map : Control = $MapView/Map
@onready var trails : MapTrails = $MapView/Map/MapTrails
var map_level_elements : Array[MapLevelElement]
#the fog over the land not reached yet, under the trails and the nodes
var fog : MapFog = null
var is_drag_pressed : bool = false
var is_dragging : bool = false
var drag_travel : Vector2 = Vector2.ZERO


func _ready() -> void:
	_get_map_level_elements()
	_add_fog()
	#the layout has its size a frame later; then the view goes to the newest level
	_centre_on_newest.call_deferred()
	_reveal_new_level()
	to_menu_button.pressed.connect(_on_to_menu_pressed)
	talents_button.pressed.connect(_on_talents_pressed)
	PlayerProgress.talents_changed.connect(_update_talents_button)
	UISignals.talents.connect(_on_talents)
	_update_talents_button()


#unspent points show on the button, so the player knows to spend them
func _update_talents_button() -> void:
	var unspent : int = PlayerProgress.get_talent_points_unspent()
	talents_button.text = TALENTS_WITH_POINTS_TEXT % unspent if unspent > 0 else TALENTS_TEXT


func _on_talents_pressed() -> void:
	UISignals.talents.emit(true)


#hidden under the talent screen: the next-level arrow and an open level panel sit above z 0 and showed through it
func _on_talents(is_open : bool) -> void:
	visible = not is_open


func _input(event: InputEvent) -> void:
	if not visible:
		return
	#typing in the console (or any text field) leaves the map where it is
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed("RightClick"):
		for map_element in map_level_elements:
			map_element._on_close_button_pressed()
	var button : InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		_on_mouse_button(button)
		return
	var motion : InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and is_drag_pressed:
		drag_travel += motion.relative
		if not is_dragging and drag_travel.length() >= DRAG_THRESHOLD:
			is_dragging = true
			UISignals.cursor_mode_requested.emit(CURSOR_SOURCE, GameCursor.Mode.GRAB)
			scroll_by(drag_travel)
		elif is_dragging:
			scroll_by(motion.relative)


func _on_mouse_button(button : InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if button.pressed:
			var step : float = WHEEL_STEP * (1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			scroll_by(Vector2(step, 0.0) if button.shift_pressed else Vector2(0.0, step))
		return
	if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if button.pressed:
		#a press on a node or an open panel is theirs, not a drag
		var hovered : Control = get_viewport().gui_get_hovered_control()
		if button.button_index == MOUSE_BUTTON_LEFT and hovered != null and hovered != map and hovered != map_view and hovered != self:
			return
		is_drag_pressed = true
		is_dragging = false
		drag_travel = Vector2.ZERO
	else:
		is_drag_pressed = false
		if is_dragging:
			UISignals.cursor_mode_requested.emit(CURSOR_SOURCE, GameCursor.Mode.POINTER)
		is_dragging = false


func _process(delta : float) -> void:
	if not visible or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var direction : Vector2 = Input.get_vector(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION, MOVE_UP_ACTION, MOVE_DOWN_ACTION)
	if direction != Vector2.ZERO:
		#the keys move the view, so the map moves the other way
		scroll_by(-direction * KEY_SCROLL_SPEED * delta)


## Moves the map by `offset` UI units, kept inside the view and on whole units (so on whole screen pixels at any
## window scale; an art pixel is 2 units).
func scroll_by(offset : Vector2) -> void:
	map.position = _clamped(map.position + offset)


## Puts `element` in the middle of the view, as far as the map's edges allow.
func centre_on(element : MapLevelElement) -> void:
	map.position = _clamped(map_view.size * 0.5 - element.position - element.size * 0.5)


func _clamped(at : Vector2) -> Vector2:
	var lowest : Vector2 = (map_view.size - map.size).min(Vector2.ZERO)
	return Vector2(clampf(at.x, lowest.x, 0.0), clampf(at.y, lowest.y, 0.0)).round()


func _centre_on_newest() -> void:
	var newest : MapLevelElement = null
	for element in map_level_elements:
		if element.visible and (newest == null or element.level_number > newest.level_number):
			newest = element
	if newest != null:
		centre_on(newest)


func _get_map_level_elements() -> void:
	for child in map.get_children():
		if child is MapLevelElement:
			map_level_elements.append(child)
			if not child.is_selected.is_connected(_on_element_is_selected):
				child.is_selected.connect(_on_element_is_selected)


func _add_fog() -> void:
	fog = MapFog.new()
	fog.name = "MapFog"
	map.add_child(fog)
	map.move_child(fog, trails.get_index())
	fog.setup(trails, _level_to_reveal())


#the level unlocked since the map was last shown (0: none)
func _level_to_reveal() -> int:
	var newest : int = PlayerProgress.level_progress
	if newest <= PlayerProgress.map_revealed_level:
		return 0
	for element in map_level_elements:
		if element.level_number == newest and element.visible:
			return newest
	return 0


#the level unlocked since the map was last shown pops in, once
func _reveal_new_level() -> void:
	var newest : int = PlayerProgress.level_progress
	if newest <= PlayerProgress.map_revealed_level:
		return

	for element in map_level_elements:
		if element.level_number == newest and element.visible:
			#the trail to it draws in first while the fog opens, then the node pops up at its end
			element.pop_in(MapTrails.REVEAL_SECONDS)
			trails.reveal(newest)
			fog.reveal()
	PlayerProgress.map_revealed_level = newest
	PlayerProgress.save_progress()


func _on_element_is_selected(map_level_element : MapLevelElement) -> void:
	for element in map_level_elements:
		if element == map_level_element:
			continue
			
		element._on_close_button_pressed()


func _on_to_menu_pressed() -> void:
	UISignals.to_menu.emit(true, name)
