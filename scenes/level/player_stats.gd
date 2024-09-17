class_name PlayerStats
extends Node

#level based stats
@export var gold : int = 6
@export var life : int = 10


func _ready() -> void:
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reach_base)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.building_placed.connect(_on_building_placed)
	UiSignals.game_play_interface_loaded.connect(_on_game_play_interface_loaded)


func _on_enemy_reach_base(enemy : Enemy) -> void:
	life -= enemy.damage
	GameSignals.resource_change.emit(life, 1)
	if life <= 0:
		lose()


func lose() -> void:
	GameSignals.lose_game.emit()


func _on_game_play_interface_loaded() -> void:
	GameSignals.resource_change.emit(gold, 0)
	GameSignals.resource_change.emit(life, 1)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	gold += enemy.gold_loot
	GameSignals.resource_change.emit(gold, 0)


func _on_building_placed(building : Building) -> void:
	gold -= building.cost
	GameSignals.resource_change.emit(gold, 0)
