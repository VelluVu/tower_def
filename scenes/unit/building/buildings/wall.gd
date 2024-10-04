class_name Wall
extends Building


const CONNECTOR : String = "CONNECTOR"
const HORIZONTAL : String = "HORIZONTAL"
const VERTICAL : String = "VERTICAL"

var neighbour_buildings : Array[Vector2i]


func _set_is_placed(value : bool) -> void:
	super(value)
	if value:
		var surrounding_cells : Array[Vector2i] = level.tile_map_main_layer.get_surrounding_cells(grid_position)
				
		for cell in surrounding_cells:
			if level.has_building_in_cell_position(cell):
				neighbour_buildings.append(cell)
		
		_update_sprite()
		
		if not GameSignals.building_destroyed.is_connected(_on_building_destroyed):
			GameSignals.building_destroyed.connect(_on_building_destroyed)
		if not GameSignals.building_placed.is_connected(_on_building_placed):
			GameSignals.building_placed.connect(_on_building_placed)


func _on_building_destroyed(building : Building) -> void:
	if not neighbour_buildings.has(building.grid_position):
		return
		
	neighbour_buildings.erase(building.grid_position)
	_update_sprite()


func _on_building_placed(building : Building) -> void:
	if neighbour_buildings.has(building.grid_position):
		return
	
	neighbour_buildings.append(building.grid_position)
	_update_sprite()


func _update_sprite() -> void:
	var has_building_left : bool = neighbour_buildings.has(grid_position - Vector2i(1,0))
	var has_building_right : bool = neighbour_buildings.has(grid_position + Vector2i(1,0))
	var has_building_up : bool = neighbour_buildings.has(grid_position - Vector2i(0,1))
	var has_building_down : bool = neighbour_buildings.has(grid_position + Vector2i(0,1))
	
	#IS BUILDING LEFT
	if has_building_left or has_building_right:
		if has_building_up or has_building_down:
			animated_sprite.play(CONNECTOR)
			return
		animated_sprite.play(HORIZONTAL)
		return
	
	if has_building_up or has_building_down:
		if has_building_left or has_building_right:
			animated_sprite.play(CONNECTOR)
			return
		animated_sprite.play(VERTICAL)
		return
