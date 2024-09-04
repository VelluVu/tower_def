class_name Builder
extends Node2D

var path_to_building_list : String = "res://scenes/building/buildings"
var current_building_option_name : String = "wall"
var is_ready_to_build : bool = false
var is_on_gui : bool = false
var placement_position : Vector2
var navigation_polygon : NavigationPolygon
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
				#print(_format_node_name_from_resource_path(item.resource_path), " ", current_building_option.buildingName)
				if _format_node_name_from_resource_path(item.resource_path) == current_building_option_name.to_lower():
					building = item.instantiate()
					building.position = get_global_mouse_position()
					building.is_placing = is_placing_building
					level.add_child(building)

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
	buildings = _get_buildings()


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
	level.navigation_region.navigation_polygon = _create_navigation_polygon_for_tilemap()
	level.navigation_region.bake_navigation_polygon()
	UiSignals.building_option_selected.connect(_start_building_placement)
	UiSignals.mouse_on_gui.connect(mouse_is_on_gui)
	print("Ready to build")
	is_ready_to_build = true


func _create_navigation_polygon_for_tilemap() -> NavigationPolygon:
	if navigation_polygon != null:
		navigation_polygon.clear()
		
	navigation_polygon = NavigationPolygon.new()
	var tileMapRect = level.tile_map.get_used_rect().abs()
	var bounds = PackedVector2Array([Vector2(tileMapRect.position.x,tileMapRect.end.y) * 16, tileMapRect.position * 16, Vector2(tileMapRect.end.x, tileMapRect.position.y) * 16, tileMapRect.end * 16])
	navigation_polygon.add_outline(bounds)
	navigation_polygon.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navigation_polygon.source_geometry_group_name = "navigation"
	navigation_polygon.agent_radius = 16.0
	return navigation_polygon


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
	
	if level.has_node("Buildings"):
		var buildings_node : Node2D = level.get_node("Buildings")
		building.reparent(buildings_node)
	else:
		var buildings_node = Node2D.new()
		buildings_node.name = "Buildings"
		level.add_child(buildings_node)
		building.reparent(buildings_node)
		
	placed_buildings.append(building)
	
	is_placing_building = false
	level.navigation_region.bake_navigation_polygon(true)


func _move_building_with_cursor():
	placement_position = snap_position_to_grid(get_global_mouse_position())
	is_valid_placement = _validate_placement_position(placement_position)	


func is_position_overlapping_other_buildings(_pos : Vector2) -> bool:
	if placed_buildings.is_empty():
		return false
	
	for placed_building in placed_buildings:
		if placed_building.position == _pos:
			return true
	return false


func is_grid_position_non_buildable(_pos : Vector2) -> bool:
	var cell_data = _get_cell_data_from_tile_pos(_pos)
	if cell_data == null:
		return true
	var is_buildable : bool = cell_data.get_custom_data("Buildable")
	return not is_buildable


func _validate_placement_position(_pos : Vector2):
	if is_grid_position_non_buildable(_pos):
		return false
	
	if is_position_overlapping_other_buildings(_pos):
		return false
	
	if building.is_overlapping_body:
		return false
	
	if building.is_overlapping_area:
		return false
	
	return true


func snap_position_to_grid(pos : Vector2):
	return level.tile_map.map_to_local(level.tile_map.local_to_map(pos))


func _get_cell_data_from_tile_pos(pos : Vector2) -> TileData:
	return level.tile_map.get_cell_tile_data(level.tile_map.local_to_map(pos))


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
