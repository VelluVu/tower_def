class_name UnitSelection
extends Area2D


@onready var outline_shader_material : ShaderMaterial = ResourceLoader.load("res://assets/shaders/shader_materials/outline_shader_material.tres")

var is_placing_building : bool = false
var selected_unit : Node2D = null

func _ready() -> void:
	GameSignals.building_placement_change.connect(_on_building_placement_change)
	GameSignals.forced_selection.connect(_on_forced_selection)
	GameSignals.building_is_placing.connect(_on_building_is_placing)
	UISignals.on_sell_selected_building_pressed.connect(_on_selected_building_sell_pressed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_move_selection_area_with_cursor()
	
	if is_placing_building:
		return
	
	if event.is_action_pressed("LeftClick"):
		_select()
	
	if event.is_action_pressed("RightClick") or event.is_action_pressed("Escape"):
		_clear_selection()


func _on_building_placement_change(is_placing : bool) -> void:
	is_placing_building = is_placing


func _on_forced_selection(selection : Node2D) -> void:
	_forced_select(selection)


func _on_building_is_placing(selection : Node2D) -> void:
	if selected_unit != null:
		_clear_selection()
	
	selected_unit = selection
	UISignals.selected_unit.emit(selected_unit.name, selected_unit.stats_manager.stats, selected_unit.icon, selected_unit.is_in_group(GroupNames.BUILDINGS))


func _move_selection_area_with_cursor() -> void:
	var cursor_position : Vector2 = get_global_mouse_position()
	global_position = cursor_position


func _forced_select(selection : Node2D) -> void:
	if selected_unit != null:
		_clear_selection()
	
	selected_unit = selection
	GameSignals.selected_unit.emit(selected_unit)
	UISignals.selected_unit.emit(selected_unit.name, selected_unit.stats_manager.stats, selected_unit.icon, selected_unit.is_in_group(GroupNames.BUILDINGS))
	selected_unit.stats_manager.stats.changed.connect(_on_selected_data_change)
	selected_unit.change_material(outline_shader_material)
	selected_unit.is_selected = true


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
	
	#print(name, " selected ", selected_unit.name, " in group ", selected_unit.get_groups())
	GameSignals.selected_unit.emit(selected_unit)
	UISignals.selected_unit.emit(selected_unit.name, selected_unit.stats_manager.stats, selected_unit.icon, selected_unit.is_in_group(GroupNames.BUILDINGS))
	selected_unit.stats_manager.stats.changed.connect(_on_selected_data_change)
	selected_unit.change_material(outline_shader_material)
	selected_unit.is_selected = true


func _clear_selection() -> void:
	if selected_unit == null:
		return
		
	#print(name, " clear selection ", selected_unit.name)
	GameSignals.deselected_unit.emit(selected_unit)
	UISignals.deselected_unit.emit(selected_unit.name, selected_unit.stats_manager.stats, selected_unit.icon, selected_unit.is_in_group(GroupNames.BUILDINGS))
	selected_unit.stats_manager.stats.changed.disconnect(_on_selected_data_change)
	selected_unit.change_material(null)
	selected_unit.is_selected = false
	selected_unit = null


func _on_selected_data_change() -> void:
	UISignals.selected_unit.emit(selected_unit.name, selected_unit.stats_manager.stats, selected_unit.icon, selected_unit.is_in_group(GroupNames.BUILDINGS))


func _on_selected_building_sell_pressed() -> void:
	if selected_unit == null:
		return
	
	selected_unit.change_material(null)
	selected_unit.is_selected = false
	GameSignals.sell_building.emit(selected_unit)
	_clear_selection()
