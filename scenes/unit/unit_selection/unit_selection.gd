class_name UnitSelection
extends Area2D


var is_placing_building : bool = false
var selected_unit : Node2D = null
var is_cursor_on_gui : bool = false


func _ready() -> void:
	GameSignals.building_placement_change.connect(_on_building_placement_change)
	GameSignals.forced_selection.connect(_on_forced_selection)
	GameSignals.building_is_placing.connect(_on_building_is_placing)
	UISignals.on_sell_selected_building_pressed.connect(_on_selected_building_sell_pressed)
	UISignals.mouse_on_gui.connect(_mouse_is_on_gui)


func _mouse_is_on_gui(is_on_ui : bool) -> void:
	is_cursor_on_gui = is_on_ui
	#wtf true false at the same time
	#print(is_cursor_on_gui)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_move_selection_area_with_cursor()
	
	if is_placing_building:
		return
	
	if event.is_action_pressed("RightClick") or event.is_action_pressed("Escape"):
		_clear_selection()
	
	if event.is_action_pressed("LeftClick") and not is_cursor_on_gui:
		_select()


func _on_building_placement_change(is_placing : bool) -> void:
	is_placing_building = is_placing
	if not is_placing_building:
		_clear_selection()


func _on_forced_selection(selection : Node2D) -> void:
	_forced_select(selection)


func _on_building_is_placing(selection : Node2D) -> void:
	if selected_unit != null:
		_clear_selection()
	
	selected_unit = selection
	GameSignals.selected_unit.emit(selected_unit)


func _move_selection_area_with_cursor() -> void:
	var cursor_position : Vector2 = get_global_mouse_position()
	global_position = cursor_position


func _forced_select(selection : Node2D) -> void:
	if selected_unit != null:
		_clear_selection()
	
	selected_unit = selection
	GameSignals.selected_unit.emit(selected_unit)


func _select() -> void:
	var overlapped_bodies : Array[Node2D] = get_overlapping_bodies()
	
	if overlapped_bodies.is_empty():
		return
	
	var closest_distance : float = 9999
	var distance_to_body : float = 0
	
	if selected_unit != null:
		_clear_selection()
	
	for body in overlapped_bodies:
		if body.is_in_group(GroupNames.SELECTABLE):
			distance_to_body = global_position.distance_to(body.global_position)
			if distance_to_body < closest_distance:
				selected_unit = body
				closest_distance = distance_to_body
	
	if selected_unit == null:
		return
	
	GameSignals.selected_unit.emit(selected_unit)


func _clear_selection() -> void:
	if selected_unit == null:
		return
		
	GameSignals.deselected_unit.emit(selected_unit)
	selected_unit = null


func _on_selected_building_sell_pressed() -> void:
	if selected_unit == null:
		return
	
	GameSignals.sell_building.emit(selected_unit)
	_clear_selection()
