class_name Builder
extends Node2D

var path_to_building_list : String = "res://scenes/building/buildings"
var current_building_option_name : String = "wall"
var is_ready_to_build : bool = false
var is_on_gui : bool = false
var gold : int = 6
var buildings_node_name = "Buildings"
var buildable_cell_custom_data_name : String = "Buildable"
var placement_position : Vector2
var building : Building = null
var level : Level
var buildings : Array[PackedScene]
var placed_buildings : Array[Building]

var is_placing_building : bool : 
	get: 
		return is_placing_building
	set(value):
		if is_placing_building == value: 
			return
		
		is_placing_building = value
		
		if not is_placing_building:
			building.is_placing = is_placing_building
			building = null
			UiSignals.building_option_deselected.emit()
		else:
			for item in buildings:
				if _format_node_name_from_resource_path(item.resource_path) == current_building_option_name.to_lower():
					building = item.instantiate()
					building.position = get_global_mouse_position()
					building.is_placing = is_placing_building
					level.add_child(building)
					placement_position = level.snap_position_to_grid(get_global_mouse_position())
					is_valid_placement = _validate_placement_position(placement_position)	

var is_valid_placement : bool :
	get:
		return is_valid_placement
	set(value):
		is_valid_placement = value
		building.position = placement_position
		building.is_valid_placement = is_valid_placement


func _ready() -> void:
	GameStateSignals.game_stop.connect(_on_game_stop)
	GameStateSignals.game_pause.connect(_on_game_pause)
	GameStateSignals.level_loaded.connect(_on_level_loaded)
	GameSignals.building_destroyed.connect(_on_building_destroyed)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	buildings = _get_buildings()


func _on_enemy_destroyed(enemy : Enemy) -> void:
	gold += enemy.gold_loot


func _on_building_destroyed(_building : Building):
	level.free_position(_building.position)
	level.all_buildings.erase(_building)
	placed_buildings.erase(_building)
	_building.queue_free()
	await get_tree().physics_frame


func _get_buildings() -> Array[PackedScene]:
	var dir := DirAccess.open(path_to_building_list)	
	if not dir:
		print("Cannot find level list from path: ", path_to_building_list)
		return buildings
	
	var level_file_names = dir.get_files()
	
	for building_file_name in level_file_names:
		if not building_file_name.contains(".tscn"):
			continue
			
		var full_path : String = path_to_building_list + "/" + building_file_name
		
		if ResourceLoader.exists(full_path):
			var has_scene : bool = false
			
			if not buildings.is_empty():
				for building_scene in buildings:
					if building_scene.get_path() == full_path:
						has_scene = true
						
			if not has_scene:
				buildings.append(ResourceLoader.load(full_path))
		else:
			print("Unable to find level resource from path: ", full_path)
			
	return buildings


func _on_game_pause(is_paused : bool) -> void:
	is_ready_to_build = not is_paused


func _on_level_loaded(_level : Level) -> void:
	level = _level
	UiSignals.building_option_selected.connect(_start_building_placement)
	UiSignals.mouse_on_gui.connect(mouse_is_on_gui)
	is_ready_to_build = true

 
func _on_game_stop() -> void:
	is_ready_to_build = false
	level = null


func mouse_is_on_gui(is_on : bool):
	is_on_gui = is_on


func _start_building_placement(building_option_name : String):
	current_building_option_name = building_option_name
	is_placing_building = true


func _format_node_name_from_resource_path(path : String):
	var formattedName : String = path.split("/")[-1]
	formattedName = formattedName.left(-5)
	return formattedName
	

func _stop_building_placement():
	var temp_building = building
	is_placing_building = false
	temp_building.queue_free()


func _place_building_by_input():
	if not is_valid_placement:
		return
	
	building.is_placed = true
	
	if level.has_node(buildings_node_name):
		var buildings_node : Node2D = level.get_node(buildings_node_name)
		building.reparent(buildings_node)
	else:
		var buildings_node = Node2D.new()
		buildings_node.name = buildings_node_name
		level.add_child(buildings_node)
		building.reparent(buildings_node)
	
	level.all_buildings.append(building)
	placed_buildings.append(building)
	level.block_position(building.global_position)
	is_placing_building = false


func _move_building_with_cursor() -> void:
	placement_position = level.snap_position_to_grid(get_global_mouse_position())
	is_valid_placement = _validate_placement_position(placement_position)	


func is_position_overlapping_other_buildings(_pos : Vector2) -> bool:
	if placed_buildings.is_empty():
		return false
	
	for placed_building in placed_buildings:
		if placed_building.position == _pos:
			return true
	return false


func is_grid_position_buildable(_pos : Vector2) -> bool:
	if level.is_position_blocked(_pos):
		return false
	var cell_data = level.get_cell_data_from_tile_pos(_pos)
	if cell_data == null:
		return false
	var is_buildable : bool = cell_data.get_custom_data(buildable_cell_custom_data_name)
	return is_buildable


func _validate_placement_position(_pos : Vector2):
	if not has_enough_gold(building.cost):
		return false
	
	if not is_grid_position_buildable(_pos):
		return false
	
	if is_position_overlapping_other_buildings(_pos):
		return false
	
	if building.is_overlapping_body:
		return false
	
	if building.is_overlapping_area:
		return false
	
	return true


func has_enough_gold(gold_needed : int) -> bool:
	if GameStateSignals.testing:
		return true
	return gold_needed <= gold


func _input(event):
	if is_on_gui:
		return
	
	if event.is_action_pressed("SelectBuilding1"):
		_start_building_placement("wall")
	
	if not is_placing_building:
		return
		
	if event.is_action_pressed("LeftClick"):
		_place_building_by_input()
		
	if event.is_action_pressed("RightClick"):
		_stop_building_placement()
		
	if event is InputEventMouseMotion:
		_move_building_with_cursor()
