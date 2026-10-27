class_name Builder
extends Node2D


const BUILDING_INDEX_OUT_OF_BOUNDS_WARNING : String = " Cannot start building index is out of buildings list bounds, index: "
const UNABLE_TO_FIND_LEVEL_LIST_ERROR : String = "Cannot find level list from path: "
const UNABLE_TO_FIND_LEVEL_RESOURCE_ERROR : String = "Unable to find level resource from path: "
const PATH_TO_BUILDINGS_FOLDER : String = "res://scenes/unit/building/buildings"
const RESOURCE_ENDING : String = ".tres"
const BUILDINGS_NODE_NAME = "Buildings"
const BUILDABLE_CELL_CUSTOM_DATA_NAME : String = "Buildable"
const SELECT_BUILDING_ONE_ACTION_NAME : String = "SelectBuilding1"
const LEFT_CLICK_ACTION_NAME : String = "LeftClick"
const RIGHT_CLICK_ACTION_NAME : String = "RightClick"
const ESCAPE_ACTION_NAME : String = "Escape"
const WALL_BUILDING_NAME : String = "wall"
const SLASH : String = "/"

@export var buildings : Array[BuildingListElement]
#the unlocked buildings in tray order; the tray slots and the select shortcuts index this list
var available_buildings : Array[BuildingListElement] = []

var is_ready_to_build : bool = false
var is_cursor_on_gui : bool = false
var is_walkable_tile_on_buildings_cells_free : bool = false
var current_building_option_index : int = 0
var grid_position : Vector2i = Vector2.ZERO
var placement_position : Vector2 = Vector2.ZERO
var current_building : Building = null
var level : Level = null
var placed_buildings : Array[Building]
var placed_building_id : int = 0
#a held left click with a wall plans a line of ghost walls, built on release
var is_dragging_line : bool = false
var drag_start_cell : Vector2i = Vector2i.ZERO
var drag_cell : Vector2i = Vector2i.ZERO
var planned_cells : Array[Vector2i] = []
var wall_line_preview : WallLinePreview = null

var is_placing_building : bool : 
	get = _get_is_placing_building,
	set = _set_is_placing_building


func has_enough_gold(gold_needed : float) -> bool:
	if GameSignals.free_build:
		return true
	return gold_needed <= level.player_stats.gold


func remove_building(_building : Building) -> void:
	level.grid.set_cell_weight(_building.grid_position, 1.0)
	placed_buildings.erase(_building)
	_building.queue_free()
	await get_tree().physics_frame
	GameSignals.building_is_removed.emit()


func _ready() -> void:
	set_physics_process(false)
	GameSignals.game_stop.connect(_on_game_stop)
	GameSignals.game_pause.connect(_on_game_pause)
	GameSignals.level_loaded.connect(_on_level_loaded)
	GameSignals.sell_building.connect(_on_building_sell)
	GameSignals.building_destroyed.connect(_on_building_destroyed)
	GameSignals.lose_game.connect(_on_lose_game)
	GameSignals.level_completed.connect(_on_level_completed)
	GameSignals.resource_change.connect(_on_resource_change)
	UISignals.game_play_interface_loaded.connect(_on_game_interface_loaded)
	_get_buildings()


func _input(event : InputEvent) -> void:
	#before the gui check, a drag can end over the build tray
	if event.is_action_released(LEFT_CLICK_ACTION_NAME) and is_dragging_line:
		_finish_wall_line()
		return

	if is_cursor_on_gui or not is_ready_to_build:
		return

	#keys typed into a text field (the console) are not build shortcuts
	if event is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit:
		return

	if event.is_action_pressed(SELECT_BUILDING_ONE_ACTION_NAME):
		_start_building_placement(0)
	
	#cancels only the line, the wall stays selected
	if is_dragging_line and (event.is_action_pressed(RIGHT_CLICK_ACTION_NAME) or event.is_action_pressed(ESCAPE_ACTION_NAME)):
		_cancel_wall_line()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(LEFT_CLICK_ACTION_NAME):
		if current_building is Wall:
			_start_wall_line()
		else:
			_place_building(current_building_option_index)
		
	if event.is_action_pressed(ESCAPE_ACTION_NAME):
		_stop_building_placement()
		
	if event.is_action_pressed(RIGHT_CLICK_ACTION_NAME):
		_stop_building_placement()
		
	if event is InputEventMouseMotion:
		_move_building_with_cursor()
		_extend_wall_line()


func _validate_placement_position(_pos : Vector2) -> bool:
	#shown red too, so a click that cannot pay does not look like a bug
	if not has_enough_gold(current_building.stats.get_stat_value(Utils.StatType.Price)):
		return false

	if not _is_position_buildable(_pos):
		return false
	
	if not current_building.placement_validator.is_valid:
		return false
	
	return true


func _on_lose_game() -> void:
	_stop_building_placement()


#the level stays running behind the completed menu, so building has to stop by hand
func _on_level_completed(_level : Level) -> void:
	_stop_building_placement()
	is_ready_to_build = false


func _on_building_sell(_building : Building) -> void:
	remove_building(_building)


func _on_building_destroyed(_building : Building) -> void:
	remove_building(_building)


#gold from a kill can make the building affordable while the cursor stands still
func _on_resource_change(_value : int, resource_index : int) -> void:
	if resource_index == 0:
		_move_building_with_cursor()


func _on_game_pause(is_paused : bool) -> void:
	is_ready_to_build = not is_paused


func _on_level_loaded(_level : Level) -> void:
	placed_buildings.clear()
	placed_building_id = 0
	#a menu freed under the cursor may never send mouse_on_gui(false)
	is_cursor_on_gui = false
	level = _level
	wall_line_preview = WallLinePreview.new()
	level.add_child(wall_line_preview)
	UISignals.building_option_selected.connect(_on_building_placement_selected)
	UISignals.building_option_deselected.connect(_on_building_placement_deselected)
	UISignals.mouse_on_gui.connect(_mouse_is_on_gui)


func _on_game_interface_loaded() -> void:
	_update_building_options()
	is_ready_to_build = true


func _update_building_options() -> void:
	#a tower unlocks in the level that introduces it and stays unlocked in replays
	var furthest_level : int = maxi(PlayerProgress.level_progress, Utils.game_control.scene_manager.current_level_number)
	available_buildings = buildings.filter(func(element : BuildingListElement) -> bool: return element.is_unlocked(furthest_level))

	for i in available_buildings.size():
		UISignals.building_option_updated.emit(i, available_buildings[i].icon)

	UISignals.buildings_updated.emit(available_buildings.size())


func _on_game_stop() -> void:
	_stop_building_placement()
	is_ready_to_build = false
	level = null
	#freed with the level
	wall_line_preview = null
	UISignals.building_option_selected.disconnect(_on_building_placement_selected)
	UISignals.building_option_deselected.disconnect(_on_building_placement_deselected)
	UISignals.mouse_on_gui.disconnect(_mouse_is_on_gui)


func _mouse_is_on_gui(is_on : bool) -> void:
	is_cursor_on_gui = is_on


func _on_building_placement_selected(building_option_index : int) -> void:
	_start_building_placement(building_option_index)


func _on_building_placement_deselected(_building_option_index : int) -> void:
	_stop_building_placement()


func _start_building_placement(building_option_index : int) -> void:
	_stop_building_placement()
	if building_option_index >= available_buildings.size():
		push_warning(name, BUILDING_INDEX_OUT_OF_BOUNDS_WARNING, building_option_index)
		UISignals.focus_building_option.emit(-1)
		_stop_building_placement()
		return
		
	current_building_option_index = building_option_index
	UISignals.focus_building_option.emit(current_building_option_index)
	is_placing_building = true


func _format_node_name_from_resource_path(path : String) -> String:
	var formattedName : String = path.split(SLASH)[-1]
	formattedName = formattedName.left(-5)
	return formattedName


func _stop_building_placement() -> void:
	_cancel_wall_line()
	is_placing_building = false


func _place_building(building_index : int) -> void:
	if not is_placing_building:
		return
	
	if not has_enough_gold(current_building.stats.get_stat_value(Utils.StatType.Price)):
		return
	
	grid_position = level.grid.world_position_to_grid(get_global_mouse_position())
	placement_position = level.grid.grid_position_to_world(grid_position)
	
	current_building.is_valid_placement = _validate_placement_position(placement_position)
	
	if not current_building.is_valid_placement:
		return
	
	current_building.is_valid_placement = false
	_instantiate_building(building_index, placement_position)


func _instantiate_building(building_index : int, position_in_world : Vector2) -> void:
	var buildings_node : Node2D = _get_buildings_container()
	var placed_building : Building = available_buildings[building_index].scene.instantiate()
	buildings_node.add_child(placed_building)
	placed_building.id = placed_building_id
	placed_building.place(position_in_world)
	placed_buildings.append(placed_building)
	placed_building_id += 1


func _start_wall_line() -> void:
	if not is_placing_building:
		return

	is_dragging_line = true
	drag_start_cell = level.grid.world_position_to_grid(get_global_mouse_position())
	drag_cell = drag_start_cell
	planned_cells.clear()
	_plan_line_cells([drag_start_cell])
	set_physics_process(true)


#plans every cell between the last and the cursor's cell, so a fast mouse leaves no gaps
func _extend_wall_line() -> void:
	if not is_dragging_line or not is_placing_building:
		return

	var cursor_cell : Vector2i = level.grid.world_position_to_grid(get_global_mouse_position())

	if cursor_cell == drag_cell:
		return

	var line : Array[Vector2i] = Geometry2D.bresenham_line(drag_cell, cursor_cell)
	line.remove_at(0)
	drag_cell = cursor_cell
	_plan_line_cells(line)


#dragging back over the line takes the last ghost away; a plan stops at what the gold pays for
#and skips a cell that would close an open enemy route
func _plan_line_cells(cells : Array[Vector2i]) -> void:
	var price : float = current_building.stats.get_stat_value(Utils.StatType.Price)
	var routes : Array[PackedVector2Array] = level.get_routes()

	for cell in cells:
		if planned_cells.size() >= 2 and cell == planned_cells[-2]:
			planned_cells.pop_back()
			continue

		if planned_cells.has(cell) or not has_enough_gold(price * (planned_cells.size() + 1)):
			continue

		if _can_build_wall_in_cell(cell) and not level.grid.would_close_route(cell, current_building.astar_weight, routes, planned_cells):
			planned_cells.append(cell)

	_update_wall_line_preview()


#a release without moving is a plain click: a single wall may close a route on purpose (blocking)
func _finish_wall_line() -> void:
	var is_click : bool = drag_cell == drag_start_cell
	var cells : Array[Vector2i] = planned_cells.duplicate()
	_cancel_wall_line()

	if not is_placing_building or not is_ready_to_build:
		return

	if is_click:
		_place_building(current_building_option_index)
		return

	var price : float = current_building.stats.get_stat_value(Utils.StatType.Price)

	for cell in cells:
		if not has_enough_gold(price):
			break

		var cell_position : Vector2 = level.grid.grid_position_to_world(cell)

		#an enemy may have walked onto a ghost; the walls before it change the routes too
		if not _can_build_wall_in_cell(cell) or not _is_cell_clear_of_bodies(cell_position):
			continue

		if level.grid.would_close_route(cell, current_building.astar_weight, level.get_routes()):
			continue

		_instantiate_building(current_building_option_index, cell_position)

	_move_building_with_cursor()


func _cancel_wall_line() -> void:
	is_dragging_line = false
	planned_cells.clear()
	set_physics_process(false)

	if wall_line_preview != null:
		wall_line_preview.clear()


#enemies move under the ghosts, so the red marks are refreshed while the line is held
func _physics_process(_delta : float) -> void:
	if is_dragging_line:
		_update_wall_line_preview()


func _update_wall_line_preview() -> void:
	var sprite : AnimatedSprite2D = current_building.animation_control
	var positions : PackedVector2Array = PackedVector2Array()
	var textures : Array[Texture2D] = []
	var blocked : Array[bool] = []

	for cell in planned_cells:
		var cell_position : Vector2 = level.grid.grid_position_to_world(cell)
		var animation : String = Wall.connector_animation(_is_wall_neighbour(cell + Vector2i.LEFT), _is_wall_neighbour(cell + Vector2i.RIGHT), _is_wall_neighbour(cell + Vector2i.UP), _is_wall_neighbour(cell + Vector2i.DOWN))
		positions.append(cell_position + sprite.position + sprite.offset)
		textures.append(sprite.sprite_frames.get_frame_texture(animation, 0) if sprite.sprite_frames.has_animation(animation) else null)
		blocked.append(not _is_cell_clear_of_bodies(cell_position))

	wall_line_preview.set_ghosts(positions, textures, blocked)


#walls join other walls and towers, like Wall._set_is_placed, but not traps
func _is_wall_neighbour(cell : Vector2i) -> bool:
	if planned_cells.has(cell):
		return true

	var building : Building = level.grid.get_building_from_cell_position(cell)
	return building != null and building is not Trap


func _can_build_wall_in_cell(cell : Vector2i) -> bool:
	return _is_position_buildable(level.grid.grid_position_to_world(cell)) and not level.grid.has_building_in_cell_position(cell)


#the preview's PlacementValidator only covers the cursor's cell, line cells ask the physics space
func _is_cell_clear_of_bodies(cell_position : Vector2) -> bool:
	var validator : PlacementValidator = current_building.placement_validator
	var query : PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = validator.collider.shape
	query.transform = Transform2D(0.0, cell_position)
	query.collision_mask = validator.collision_mask
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _move_building_with_cursor() -> void:
	if not is_placing_building:
		return
		
	grid_position = level.grid.world_position_to_grid(get_global_mouse_position())
	placement_position = level.grid.grid_position_to_world(grid_position)
	
	current_building.global_position = placement_position
	current_building.is_valid_placement = _validate_placement_position(placement_position)



func _is_position_buildable(_pos : Vector2) -> bool:
	if not level.grid.is_position_in_bounds(_pos):
		return false
	
	var is_buildable = level.grid.is_position_buildable(_pos) if current_building is not Trap else level.grid.is_position_walkable(_pos)
	
	return is_buildable


func _get_is_placing_building() -> bool:
	return is_placing_building


func _set_is_placing_building(value : bool) -> void:
	if is_placing_building == value: 
		return
		
	is_placing_building = value
	
	if is_placing_building:
		if current_building == null:
			current_building = available_buildings[current_building_option_index].scene.instantiate()
			level.add_child(current_building)
			_move_building_with_cursor()
	
	current_building.is_placing = is_placing_building
	
	if not is_placing_building:
		if current_building != null:
			current_building.queue_free()
			current_building = null
	
	GameSignals.building_placement_change.emit(is_placing_building)


func _get_buildings_container() -> Node2D:
	var buildings_node : Node2D = null
	
	if level.has_node(BUILDINGS_NODE_NAME):
		buildings_node = level.get_node(BUILDINGS_NODE_NAME)
	else:
		buildings_node = Node2D.new()
		buildings_node.name = BUILDINGS_NODE_NAME
		level.add_child(buildings_node)
	
	buildings_node.y_sort_enabled = true
	return buildings_node


func _get_buildings() -> void:
	var dir := DirAccess.open(PATH_TO_BUILDINGS_FOLDER)
	
	if not dir:
		push_error(UNABLE_TO_FIND_LEVEL_LIST_ERROR, PATH_TO_BUILDINGS_FOLDER)
		return
	
	var file_names = dir.get_files()
	
	for file_name in file_names:
		if file_name.ends_with(".remap"):
			file_name = file_name.replace(".remap", "")
		
		if not file_name.contains(RESOURCE_ENDING):
			continue
		
		var full_path : String = PATH_TO_BUILDINGS_FOLDER + SLASH + file_name
		
		if not ResourceLoader.exists(full_path):
			push_error(UNABLE_TO_FIND_LEVEL_RESOURCE_ERROR, full_path)
			continue
		
		#skip elements already set in the inspector
		if buildings.any(func(element : BuildingListElement) -> bool: return element.resource_path == full_path):
			continue

		buildings.append(ResourceLoader.load(full_path))
	buildings.sort_custom(sort_by_id)


func sort_by_id(a : BuildingListElement, b : BuildingListElement) -> bool:
	return a.id < b.id
