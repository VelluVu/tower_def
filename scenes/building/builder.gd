class_name Builder
extends Node2D


const BUILDING_INDEX_OUT_OF_BOUNDS_WARNING : String = " Cannot start building index is out of buildings list bounds, index: "
const UNABLE_TO_FIND_LEVEL_LIST_ERROR : String = "Cannot find level list from path: "
const UNABLE_TO_FIND_LEVEL_RESOURCE_ERROR : String = "Unable to find level resource from path: "
const PATH_TO_BUILDINGS_FOLDER : String = "res://scenes/building/buildings"
const SCENE_ENDING : String = ".tscn"
const BUILDINGS_NODE_NAME = "Buildings"
const BUILDABLE_CELL_CUSTOM_DATA_NAME : String = "Buildable"
const SELECT_BUILDING_ONE_ACTION_NAME : String = "SelectBuilding1"
const LEFT_CLICK_ACTION_NAME : String = "LeftClick"
const RIGHT_CLICK_ACTION_NAME : String = "RightClick"
const ESCAPE_ACTION_NAME : String = "Escape"
const WALL_BUILDING_NAME : String = "wall"
const SLASH : String = "/"

var is_ready_to_build : bool = false
var is_cursor_on_gui : bool = false
var current_building_option_index : int = 0
var placement_position : Vector2 = Vector2.ZERO
var buildings : Array[PackedScene]
var current_building : Building = null
var level : Level = null
var placed_buildings : Array[Building]

var is_placing_building : bool : 
	get = _get_is_placing_building,
	set = _set_is_placing_building

var is_valid_placement : bool :
	get = _get_is_valid_placement,
	set = _set_is_valid_placement


func has_enough_gold(gold_needed : int) -> bool:
	if GameStateSignals.testing:
		return true
	return gold_needed <= level.player_stats.gold


func _ready() -> void:
	GameStateSignals.game_stop.connect(_on_game_stop)
	GameStateSignals.game_pause.connect(_on_game_pause)
	GameStateSignals.level_loaded.connect(_on_level_loaded)
	GameSignals.building_destroyed.connect(_on_building_destroyed)
	buildings = _get_buildings()


func _input(event):
	if is_cursor_on_gui:
		return
	
	if event.is_action_pressed(SELECT_BUILDING_ONE_ACTION_NAME):
		_start_building_placement(0)
	
	if event.is_action_pressed(LEFT_CLICK_ACTION_NAME):
		_place_building(current_building_option_index)
		
	if event.is_action_pressed(ESCAPE_ACTION_NAME):
		_stop_building_placement()
		
	if event.is_action_pressed(RIGHT_CLICK_ACTION_NAME):
		_stop_building_placement()
		
	if event is InputEventMouseMotion:
		_move_building_with_cursor(current_building)


func _validate_placement_position(_pos : Vector2):
	if not _is_grid_position_buildable(_pos):
		return false
	
	if _is_position_overlapping_other_buildings(_pos):
		return false
	
	return true


func _on_building_destroyed(_building : Building):
	level.free_position(_building.position)
	placed_buildings.erase(_building)
	_building.queue_free()
	await get_tree().physics_frame


func _on_game_pause(is_paused : bool) -> void:
	is_ready_to_build = not is_paused


func _on_level_loaded(_level : Level) -> void:
	placed_buildings.clear()
	level = _level
	UiSignals.building_option_selected.connect(_on_building_placement_selected)
	UiSignals.building_option_deselected.connect(_on_building_placement_deselected)
	UiSignals.mouse_on_gui.connect(_mouse_is_on_gui)
	is_ready_to_build = true


func _on_game_stop() -> void:
	is_ready_to_build = false
	level = null
	UiSignals.building_option_selected.disconnect(_on_building_placement_selected)
	UiSignals.building_option_deselected.disconnect(_on_building_placement_deselected)
	UiSignals.mouse_on_gui.disconnect(_mouse_is_on_gui)


func _mouse_is_on_gui(is_on : bool) -> void:
	is_cursor_on_gui = is_on


func _on_building_placement_selected(building_option_index : int) -> void:
	_start_building_placement(building_option_index)


func _on_building_placement_deselected(_building_option_index : int) -> void:
	_stop_building_placement()


func _start_building_placement(building_option_index : int) -> void:
	if building_option_index >= buildings.size():
		push_warning(name, BUILDING_INDEX_OUT_OF_BOUNDS_WARNING, building_option_index)
		_stop_building_placement()
		return
		
	current_building_option_index = building_option_index
	is_placing_building = true


func _format_node_name_from_resource_path(path : String):
	var formattedName : String = path.split(SLASH)[-1]
	formattedName = formattedName.left(-5)
	return formattedName
	

func _stop_building_placement():
	is_placing_building = false


func _place_building(building_index : int) -> void:
	if not is_placing_building:
		return
	
	if not has_enough_gold(current_building.cost):
		return
		
	placement_position = level.snap_position_to_grid(get_global_mouse_position())
	is_valid_placement = _validate_placement_position(placement_position)
	
	if not is_valid_placement:
		return
	
	var buildings_node : Node2D = _find_or_create_buildings_container()
	var placed_building : Building = buildings[building_index].instantiate()
	print(placed_building.global_position, " ", placed_building.position)
	buildings_node.add_child(placed_building)
	placed_building.position = placement_position
	placed_building.is_placing = false
	level.block_position(placed_building.position)
	placed_buildings.append(placed_building)
	GameSignals.building_placed.emit(placed_building)


func _find_or_create_buildings_container() -> Node2D:
	var buildings_node : Node2D = null
	
	if level.has_node(BUILDINGS_NODE_NAME):
		buildings_node = level.get_node(BUILDINGS_NODE_NAME)
	else:
		buildings_node = Node2D.new()
		buildings_node.name = BUILDINGS_NODE_NAME
		level.add_child(buildings_node)
		
	return buildings_node


func _move_building_with_cursor(building : Building) -> void:
	if not is_placing_building:
		return
		
	placement_position = level.snap_position_to_grid(get_global_mouse_position())
	is_valid_placement = _validate_placement_position(placement_position)
	building.position = placement_position
	building.is_valid_placement = is_valid_placement


func _is_position_overlapping_other_buildings(_pos : Vector2) -> bool:
	if placed_buildings.is_empty():
		return false
	
	for placed_building in placed_buildings:
		if placed_building.position == _pos:
			return true
	return false


func _is_grid_position_buildable(_pos : Vector2) -> bool:
	if level.is_position_blocked(_pos):
		return false
	var cell_data = level.get_cell_data_from_tile_pos(_pos)
	if cell_data == null:
		return false
	var is_buildable : bool = cell_data.get_custom_data(BUILDABLE_CELL_CUSTOM_DATA_NAME)
	return is_buildable


func _get_is_placing_building() -> bool:
	return is_placing_building


func _set_is_placing_building(value : bool) -> void:
	if is_placing_building == value: 
		return
		
	is_placing_building = value
	
	if is_placing_building:
		if current_building == null:
			current_building = buildings[current_building_option_index].instantiate()
			add_child(current_building)
			_move_building_with_cursor(current_building)
	
	current_building.is_placing = is_placing_building
	
	if not is_placing_building:
		if current_building != null:
			current_building.queue_free()
			current_building = null
	
	UiSignals.building_placement_change.emit(is_placing_building)


func _get_is_valid_placement() -> bool:
	return is_valid_placement


func _set_is_valid_placement(value : bool) -> void:
	if is_valid_placement == value:
		return
		
	is_valid_placement = value


func _get_buildings() -> Array[PackedScene]:
	var dir := DirAccess.open(PATH_TO_BUILDINGS_FOLDER)	
	if not dir:
		push_error(UNABLE_TO_FIND_LEVEL_LIST_ERROR, PATH_TO_BUILDINGS_FOLDER)
		return buildings
	
	var level_file_names = dir.get_files()
	
	for building_file_name in level_file_names:
		if not building_file_name.contains(SCENE_ENDING):
			continue
			
		var full_path : String = PATH_TO_BUILDINGS_FOLDER + SLASH + building_file_name
		
		if ResourceLoader.exists(full_path):
			var has_scene : bool = false
			
			if not buildings.is_empty():
				for building_scene in buildings:
					if building_scene.get_path() == full_path:
						has_scene = true
						
			if not has_scene:
				buildings.append(ResourceLoader.load(full_path))
		else:
			push_error(UNABLE_TO_FIND_LEVEL_RESOURCE_ERROR, full_path)
			
	return buildings
