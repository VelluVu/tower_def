class_name EnemySummon
extends RefCounted

## Enemies made in the middle of a level by another enemy (egg sacs, hatchlings, tunnels, a swarm):
## they go next to the summoner (under its spawner), walk to the same castle, and flyers fly straight.

const NOT_AN_ENEMY_WARNING : String = " summoned scene is not an Enemy: "


static func summon(scene : PackedScene, summoner : Enemy, at_position : Vector2) -> Enemy:
	var spawned : Node = scene.instantiate()
	if spawned is not Enemy:
		push_warning(summoner.name, NOT_AN_ENEMY_WARNING, scene.resource_path)
		spawned.queue_free()
		return null

	var enemy : Enemy = spawned
	enemy.end_point = summoner.end_point
	var parent : Node = summoner.get_parent()
	enemy.position = parent.to_local(at_position) if parent is Node2D else at_position
	parent.add_child(enemy)
	return enemy


## count enemies spread over the given cell and its free neighbours
static func summon_around(scene : PackedScene, summoner : Enemy, count : int, cell : Vector2i) -> Array[Enemy]:
	var grid : LevelGrid = summoner.level.grid
	var cells : Array[Vector2i] = [cell]
	cells.append_array(grid.get_walkable_surrounding_cells(cell))
	var summoned : Array[Enemy] = []

	for i in count:
		var enemy : Enemy = summon(scene, summoner, grid.grid_position_to_world(cells[i % cells.size()]))
		if enemy != null:
			summoned.append(enemy)

	return summoned
