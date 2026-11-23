class_name Scorch
extends Node2D

## Where a lava spitter's glob lands the ground burns: for a while nothing can be built on those cells (they stay
## walkable). Cells that something else already overrides (lava, cooled rock) or that hold a building are left alone.

const COLOR : Color = Color(0.36, 0.11, 0.09, 0.55)
const EMBER : Color = Color("f77622")

var level : Level = null
var cells : Array[Vector2i] = []
var timer : CustomTimer = null


## Scorches the free cells within radius tiles of the point (at least its own cell).
static func make(target_level : Level, at : Vector2, radius : float, seconds : float) -> Scorch:
	var grid : LevelGrid = target_level.grid
	var centre : Vector2i = grid.world_position_to_grid(at)
	var reach : int = maxi(roundi(radius), 0)
	var scorch : Scorch = Scorch.new()
	scorch.level = target_level
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var cell : Vector2i = centre + Vector2i(dx, dy)
			if Vector2(dx, dy).length() > radius + 0.01 and (dx != 0 or dy != 0):
				continue
			#walkable too: OnlyWalkable on a build-only tile would open it to the enemies' paths
			if grid.cell_overrides.has(cell) or grid.has_building_in_cell_position(cell) \
					or not grid.is_position_buildable(grid.grid_position_to_world(cell)) or not grid.is_cell_walkable(cell):
				continue
			scorch.cells.append(cell)
	if scorch.cells.is_empty():
		scorch.free()
		return null
	for cell in scorch.cells:
		grid.set_cell_override(cell, Utils.TileType.OnlyWalkable)
	target_level.add_child(scorch)
	scorch.timer.unscaled_base_value = seconds
	scorch.timer.start()
	return scorch


func _init() -> void:
	z_index = -1
	timer = CustomTimer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_end)


func _end() -> void:
	if is_instance_valid(level):
		for cell in cells:
			if level.grid.cell_overrides.get(cell, -1) == Utils.TileType.OnlyWalkable:
				level.grid.clear_cell_override(cell)
	queue_free()


#burnt patches with an ember in the middle, in the level's coordinates
func _draw() -> void:
	var half : float = Utils.TILE_SIZE * 0.5
	for cell in cells:
		var centre : Vector2 = level.grid.grid_position_to_world(cell)
		draw_rect(Rect2(centre - Vector2(half - 2, half - 2), Vector2(Utils.TILE_SIZE - 4, Utils.TILE_SIZE - 4)), COLOR)
		draw_rect(Rect2(centre - Vector2(1, 1), Vector2(2, 2)), EMBER)
