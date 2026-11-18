class_name LavaField
extends Node

## The lava of a volcano level (created by Level when LevelData.lava_cools or the level has a Fissure). Lava is the
## water layer there: blocking, not buildable. A Frost tower or Frost wall next to a lava cell (8 neighbours) cools it,
## COOL_SECONDS for one, faster with more of them: a lava river turns into obsidian rock (buildable, not walkable), lava
## an eruption poured over the ground turns back into the ground it was. Fissures erupt through erupt().

const COOL_SECONDS : float = 10.0
const TICK_SECONDS : float = 0.5
## The water layer's open water pieces (no shore, no foam: level_tiles.py CENTERS); with the volcano's water tile
## set they are lava.
const LAVA_SOURCE : int = 2
const LAVA_TILES : Array[Vector2i] = [Vector2i(0, 37), Vector2i(0, 38), Vector2i(0, 39), Vector2i(0, 40)]
## The ground sheet's bog block, cooled black glass in the volcano's ground tile set.
const OBSIDIAN_SOURCE : int = 2
const OBSIDIAN_TILE : Vector2i = Vector2i(40, 0)
## Share of a building's max health an eruption burns away when lava flows over its cell.
const ERUPTION_DAMAGE_SHARE : float = 0.75
const NEIGHBOURS : Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

signal cell_cooled(cell : Vector2i)

var level : Level = null
#cooling progress per lava cell, in seconds of one cooler
var cooling : Dictionary[Vector2i, float] = {}
#cells an eruption flooded: they turn back into their ground when cooled
var erupted : Dictionary[Vector2i, bool] = {}
var tick_timer : CustomTimer = null

var water_layer : TileMapLayer :
	get:
		return level.tiles.water_layer


func _ready() -> void:
	level = get_parent()
	tick_timer = CustomTimer.new()
	add_child(tick_timer)
	tick_timer.unscaled_base_value = TICK_SECONDS
	tick_timer.timeout.connect(_tick)
	tick_timer.start()


func is_lava(cell : Vector2i) -> bool:
	return water_layer.get_cell_source_id(cell) != -1


## Floods the cells with lava: no walking, no building, and what stands there burns. A cell whose lava would leave a
## spawner without any road to its castle stays dry.
func erupt(cells : Array[Vector2i]) -> void:
	for cell in cells:
		if is_lava(cell) or level.grid.reserved_cells.has(cell):
			continue
		level.grid.set_cell_override(cell, Utils.TileType.Blocking)
		if not _all_routes_open():
			level.grid.clear_cell_override(cell)
			continue
		erupted[cell] = true
		water_layer.set_cell(cell, LAVA_SOURCE, LAVA_TILES[absi(cell.x * 7 + cell.y * 3) % LAVA_TILES.size()])
		var building : Building = level.grid.get_building_from_cell_position(cell)
		if building != null and not building.is_dead:
			var burn : DamageData = DamageData.new()
			burn.damage_type = Utils.DamageType.Fire
			burn.damage = building.stats.get_stat_value(Utils.StatType.MaxHealth) * ERUPTION_DAMAGE_SHARE
			building.take_damage(burn)
			burn.free()
	GameSignals.astar_grid_updated.emit()


## Lava an eruption left that has not been cooled yet: it sets by itself (a fissure's lava_waves ran out).
func settle(cells : Array[Vector2i]) -> void:
	var changed : bool = false
	for cell in cells:
		if erupted.has(cell) and is_lava(cell):
			cool(cell)
			changed = true
	if changed:
		GameSignals.astar_grid_updated.emit()


func cool(cell : Vector2i) -> void:
	water_layer.erase_cell(cell)
	cooling.erase(cell)
	if erupted.erase(cell):
		level.grid.clear_cell_override(cell)
	else:
		level.tiles.ground_layer.set_cell(cell, OBSIDIAN_SOURCE, OBSIDIAN_TILE)
		level.grid.set_cell_override(cell, Utils.TileType.OnlyBuildable)
	cell_cooled.emit(cell)


func _tick() -> void:
	var reopened : bool = false
	for building in level.all_buildings:
		if not is_instance_valid(building) or building.is_dead or not building.is_placed or not is_cooler(building):
			continue
		var cell : Vector2i = level.grid.world_position_to_grid(building.global_position)
		for offset in NEIGHBOURS:
			var lava : Vector2i = cell + offset
			if not is_lava(lava):
				continue
			cooling[lava] = cooling.get(lava, 0.0) + TICK_SECONDS
			if cooling[lava] >= COOL_SECONDS:
				reopened = reopened or erupted.has(lava)
				cool(lava)
	if reopened:
		GameSignals.astar_grid_updated.emit()


func _all_routes_open() -> bool:
	for spawner in level.get_spawners():
		if spawner.end_point != null and not level.grid.reaches(spawner.global_position, spawner.end_point.global_position):
			return false
	return true


## Frost towers and Frost walls cool lava.
static func is_cooler(building : Building) -> bool:
	if building is Wall:
		return building.element == Utils.Element.Frost
	return building is Tower and building.evolve_tree != null and building.evolve_tree.is_element_chosen \
		and building.evolve_tree.evolve_element == Utils.Element.Frost
