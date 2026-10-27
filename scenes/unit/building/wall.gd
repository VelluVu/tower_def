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
		var surrounding_cells : Array[Vector2i] = level.grid.get_surrounding_cells(grid_position)
				
		for cell in surrounding_cells:
			if level.grid.has_building_in_cell_position(cell):
				if level.grid.get_building_from_cell_position(cell) is Trap:
					continue
				neighbour_buildings.append(cell)
		
		_update_sprite()
		
		if not GameSignals.building_destroyed.is_connected(_on_building_removed):
			GameSignals.building_destroyed.connect(_on_building_removed)
		if not GameSignals.sell_building.is_connected(_on_building_removed):
			GameSignals.sell_building.connect(_on_building_removed)
		if not GameSignals.building_placed.is_connected(_on_building_placed):
			GameSignals.building_placed.connect(_on_building_placed)


func _on_building_removed(building : Building) -> void:
	if building is Trap:
		return
		
	if not neighbour_buildings.has(building.grid_position):
		return
		
	neighbour_buildings.erase(building.grid_position)
	_update_sprite()


func _on_building_placed(building : Building) -> void:
	if building is Trap:
		return
	
	if neighbour_buildings.has(building.grid_position):
		return
	
	neighbour_buildings.append(building.grid_position)
	_update_sprite()


func _update_sprite() -> void:
	var has_building_left : bool = neighbour_buildings.has(grid_position - Vector2i(1,0))
	var has_building_right : bool = neighbour_buildings.has(grid_position + Vector2i(1,0))
	var has_building_up : bool = neighbour_buildings.has(grid_position - Vector2i(0,1))
	var has_building_down : bool = neighbour_buildings.has(grid_position + Vector2i(0,1))
	animation_control.play(connector_animation(has_building_left, has_building_right, has_building_up, has_building_down))


#the wall piece that joins the neighbouring buildings; the line preview uses it for ghost walls too
static func connector_animation(left : bool, right : bool, up : bool, down : bool) -> String:
	if left and right and down and up:
		return CONNECTOR_LRDU
	
	if not left and not right and not up and not down:
		return CONNECTOR_X
	
	if left and right and not down and not up:
		return HORIZONTAL
	
	if up and down and not left and not right:
		return VERTICAL
	
	if left and not right and not up and not down:
		return HORIZONTAL_END_R
	
	if right and not left and not up and not down:
		return HORIZONTAL_END_L
	
	if up and not right and not left and not down:
		return VERTICAL_END_D
	
	if down and not right and not left and not up:
		return VERTICAL_END_U
	
	if left and right and up and not down:
		return CONNECTOR_LRU
	
	if left and right and down and not up:
		return CONNECTOR_LRD
	
	if left and up and down and not right:
		return CONNECTOR_LUD
	
	if right and up and down and not left:
		return CONNECTOR_RUD
	
	if left and up and not right and not down:
		return CONNECTOR_LU
	
	if left and down and not right and not up:
		return CONNECTOR_LD
	
	if right and down and not left and not up:
		return CONNECTOR_RD
	
	if right and up and not left and not down:
		return CONNECTOR_UR

	return CONNECTOR_X
