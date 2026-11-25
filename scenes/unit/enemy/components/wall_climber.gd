class_name WallClimber
extends Node

## The wall crawler goes over walls: its path counts a wall's cell as `wall_weight` (the open road is 1, a building
## 100), its body never bumps into walls, and it never stops to attack one. Towers still block it like anyone.

@export var wall_weight : float = 1.2

@onready var enemy : Enemy = get_parent()


func _ready() -> void:
	enemy.climbs_walls = true
	enemy.wall_path_weight = wall_weight
	if enemy.level != null:
		for building in enemy.level.all_buildings:
			_pass_through(building)
	GameSignals.building_placed.connect(_pass_through)


#untyped: the level's list can hold a building freed this frame
func _pass_through(building) -> void:
	if is_instance_valid(building) and building is Wall:
		enemy.add_collision_exception_with(building)
