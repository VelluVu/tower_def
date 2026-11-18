class_name EruptAbility
extends EnemyAbility

## The Ashen Wyrm on the ground (66-33%): it stamps (ATTACK) and the ground under up to `targets` towers near it
## cracks, then erupts after warn_time (the level's LavaField floods those cells; the towers burn). The cracks stay as a
## Fissure, so the lava sets again after its waves or when a Frost tower cools it.

## In tiles.
@export var reach : float = 3.0
@export var targets : int = 2
@export var warn_time : float = 1.5

var picked : Array[Vector2i] = []


func _can_use() -> bool:
	picked = _pick_cells()
	return not picked.is_empty()


func _run() -> void:
	var cells : Array[Vector2i] = picked.duplicate()
	if not await _play_and_wait(GlobalAnimationNames.ATTACK_ANIMATION):
		return
	var level : Level = enemy.level
	var cracks : Fissure = Fissure.new()
	cracks.cells = cells
	level.add_child(cracks)
	cracks._set_warning(true)
	if not await _wait(warn_time):
		cracks.queue_free()
		return
	var lava_field : LavaField = cracks.get_lava_field()
	cracks._set_warning(false)
	if lava_field != null:
		lava_field.erupt(cells)
		cracks.waves_since_eruption = 0
	_finish()


func _pick_cells() -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	if enemy == null or enemy.level == null or enemy.is_flying or enemy.level.get_node_or_null(Level.LAVA_FIELD_NAME) == null:
		return cells
	var range_px : float = reach * Utils.TILE_SIZE
	var towers : Array = enemy.level.all_buildings.filter(func(building : Building) -> bool:
		return is_instance_valid(building) and building is Tower and not building.is_dead and building.is_placed \
			and building.global_position.distance_to(enemy.global_position) <= range_px)
	towers.sort_custom(func(a : Building, b : Building) -> bool:
		return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position))
	for tower in towers.slice(0, targets):
		cells.append(enemy.level.grid.world_position_to_grid(tower.global_position))
	return cells
