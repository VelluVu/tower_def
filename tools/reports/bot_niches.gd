extends RefCounted

## What the bots know of the towers' niches (TowerNiches, 2026-11-26): a route cell is worth more to a tower that
## shines there: the Breather in a corridor, the traps on maze cells (the Nova's, Spotter's and Mortar's cell bonuses
## were removed 2026-11-27). Both bots weight the route cells they cover by it (soak_level._best_tower_cell, smart_play._covered);
## `extra` cells count as blocked, so a wall the bot is weighing makes its corridors and corners before it is built.
## The Harpooner's prey (flyers, fast runners) and the Shredder's (pinned enemies, elites) are per wave, not per cell:
## smart_play reads them from the coming wave.

const TRAPS : Array[String] = ["LeopardTrap", "EggBomb", "SpikeField"]
## Keys whose cells have a niche (the rest weigh every cell 1).
const CELL_KEYS : Array[String] = ["PuffeBreather", "LeopardTrap", "EggBomb", "SpikeField"]
## A Harpooner harpoon past the first lands on another target this often (a wave rarely comes one at a time).
const EXTRA_HARPOON_SHARE : float = 0.6
## Each building a Buffer keeps buffed: one throw a THROW_SECONDS, each holding BUFF_SECONDS.
const BUFFER_HELD : float = Buffer.BUFF_SECONDS / Buffer.THROW_SECONDS


## Scenes whose root node is named other than their file (keys are root names).
const SCENE_KEYS : Dictionary[String, String] = {"puffe_elder": "PuffeElderDrake", "puffe_hoard": "PuffeHoardKeeper"}


static func key_of_scene(scene_name : String) -> String:
	return SCENE_KEYS.get(scene_name, scene_name.to_pascal_case())


static func has_cell_niche(key : String) -> bool:
	return CELL_KEYS.has(key)


## The niche factor of a route cell for a tower kind. maze: the bot's maze cells (soak_level._maze_cells, with the
## weighed walls in); extra: weighed walls; element: the tower's element name ("" before it has one).
static func cell_factor(grid : LevelGrid, key : String, cell : Vector2i, maze : Dictionary, extra : Dictionary = {}, element : String = "") -> float:
	#the other towers' cell bonuses were removed 2026-11-27; the Breather's and the traps' are left
	if key == "PuffeBreather":
		return 1.0 + TowerNiches.BREATHER_CORRIDOR_BONUS if is_corridor(grid, cell, extra) else 1.0
	if TRAPS.has(key):
		return 1.0 + TowerNiches.TRAP_MAZE_BONUS if maze.has(cell) else 1.0
	return 1.0


## Enemies go slow here: a maze cell or slow ground (the Mortar's and the Shredder's pinned enemies).
static func is_slowed(grid : LevelGrid, cell : Vector2i, maze : Dictionary) -> bool:
	return maze.has(cell) or grid.get_move_speed_factor(cell) < 1.0


## LevelGrid.is_corridor_cell with the weighed walls in.
static func is_corridor(grid : LevelGrid, cell : Vector2i, extra : Dictionary = {}) -> bool:
	return (_is_side_blocked(grid, cell + Vector2i.LEFT, extra) and _is_side_blocked(grid, cell + Vector2i.RIGHT, extra)) \
		or (_is_side_blocked(grid, cell + Vector2i.UP, extra) and _is_side_blocked(grid, cell + Vector2i.DOWN, extra))


static func _is_side_blocked(grid : LevelGrid, cell : Vector2i, extra : Dictionary) -> bool:
	if extra.has(cell) or not grid.is_cell_walkable(cell):
		return true
	var building : Building = grid.get_building_from_cell_position(cell)
	return building != null and building is not Trap


## Every route cell's factor for the kind, for weighing many candidate cells against the same routes.
static func route_factors(grid : LevelGrid, key : String, routes : Array[Vector2i], maze : Dictionary, element : String = "") -> Dictionary[Vector2i, float]:
	var factors : Dictionary[Vector2i, float] = {}
	if not has_cell_niche(key):
		return factors
	for cell in routes:
		var factor : float = cell_factor(grid, key, cell, maze, {}, element)
		if factor != 1.0:
			factors[cell] = factor
	return factors


## A Harpooner's harpoons at an evolve tier (one more per tier, LaunchProjectile._launch_extra_harpoons), as hits;
## multiplier: Twin Harpoons (1 + TalentEffect.Kind.HarpoonMultiplier).
static func harpoon_hits(tier : int, multiplier : float = 1.0) -> float:
	var harpoons : float = (1.0 + tier * LaunchProjectile.HARPOONS_PER_TIER) * multiplier
	return 1.0 + (harpoons - 1.0) * EXTRA_HARPOON_SHARE


## The share of the time a Buffer keeps each of this many covered buildings buffed (its throws go round them).
static func buffer_uptime(covered : int) -> float:
	return 1.0 if covered <= 0 else minf(1.0, BUFFER_HELD / covered)
