class_name Wall
extends Building


const CONNECTOR_LRDU : String = "CONNECTOR_LRDU"
const CONNECTOR_LRD : String = "CONNECTOR_LRD"
const CONNECTOR_RD : String = "CONNECTOR_RD"
const CONNECTOR_LRU : String = "CONNECTOR_LRU"
const CONNECTOR_LU : String = "CONNECTOR_LU"
const CONNECTOR_LD : String = "CONNECTOR_LD"
const CONNECTOR_LUD : String = "CONNECTOR_LUD"
const CONNECTOR_RUD : String = "CONNECTOR_RUD"
const CONNECTOR_UR : String = "CONNECTOR_UR"
const CONNECTOR_X : String = "CONNECTOR_X"

const HORIZONTAL : String = "HORIZONTAL"
const HORIZONTAL_END_R : String = "HORIZONTAL_END_R"
const HORIZONTAL_END_L : String = "HORIZONTAL_END_L"

const VERTICAL : String = "VERTICAL"
const VERTICAL_END_D : String = "VERTICAL_END_D"
const VERTICAL_END_U : String = "VERTICAL_END_U"

var neighbour_buildings : Array[Vector2i]


func _set_is_placed(value : bool) -> void:
	super(value)
	if value:
		var surrounding_cells : Array[Vector2i] = level.tiles.ground_layer.get_surrounding_cells(grid_position)
				
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
	
	if has_building_left and has_building_right and has_building_down and has_building_up:
		animation_control.play(CONNECTOR_LRDU)
		return
	
	if not has_building_left and not has_building_right and not has_building_up and not has_building_down:
		animation_control.play(CONNECTOR_X)
		return
	
	if has_building_left and has_building_right and not has_building_down and not has_building_up:
		animation_control.play(HORIZONTAL)
		return
	
	if has_building_up and has_building_down and not has_building_left and not has_building_right:
		animation_control.play(VERTICAL)
		return
	
	if has_building_left and not has_building_right and not has_building_up and not has_building_down:
		animation_control.play(HORIZONTAL_END_R)
		return
	
	if has_building_right and not has_building_left and not has_building_up and not has_building_down:
		animation_control.play(HORIZONTAL_END_L)
		return
	
	if has_building_up and not has_building_right and not has_building_left and not has_building_down:
		animation_control.play(VERTICAL_END_D)
		return
	
	if has_building_down and not has_building_right and not has_building_left and not has_building_up:
		animation_control.play(VERTICAL_END_U)
		return
	
	if has_building_left and has_building_right and has_building_up and not has_building_down:
		animation_control.play(CONNECTOR_LRU)
		return
	
	if has_building_left and has_building_right and has_building_down and not has_building_up:
		animation_control.play(CONNECTOR_LRD)
		return
	
	if has_building_left and has_building_up and has_building_down and not has_building_right:
		animation_control.play(CONNECTOR_LUD)
		return
	
	if has_building_right and has_building_up and has_building_down and not has_building_left:
		animation_control.play(CONNECTOR_RUD)
		return
	
	if has_building_left and has_building_up and not has_building_right and not has_building_down:
		animation_control.play(CONNECTOR_LU)
		return
	
	if has_building_left and has_building_down and not has_building_right and not has_building_up:
		animation_control.play(CONNECTOR_LD)
		return
	
	if has_building_right and has_building_down and not has_building_left and not has_building_up:
		animation_control.play(CONNECTOR_RD)
		return
	
	if has_building_right and has_building_up and not has_building_left and not has_building_down:
		animation_control.play(CONNECTOR_UR)
