class_name DeathBurst
extends Node

## The bloater's end: when it is killed (not when it leaks) it bursts and damages every building
## near it, walls too, so it must die away from the maze it cannot get through.

## In tiles from the enemy to the building.
@export var radius : float = 1.5
@export var damage : float = 4.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Poison

@onready var enemy : Enemy = get_parent()


func _ready() -> void:
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func _on_enemy_destroyed(destroyed : Enemy) -> void:
	if destroyed != enemy or not enemy.is_dead or enemy.level == null:
		return

	var reach : float = radius * Utils.TILE_SIZE
	for building in enemy.level.all_buildings.duplicate():
		if not is_instance_valid(building) or building.is_dead or building is Trap:
			continue
		if building.global_position.distance_to(enemy.global_position) > reach:
			continue
		var hit : DamageData = DamageData.new()
		hit.damage_type = damage_type
		hit.damage = damage
		building.take_damage(hit)
		hit.free()
