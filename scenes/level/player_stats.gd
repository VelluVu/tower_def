class_name PlayerStats
extends Node

#level based player resources
@export var gold : float = 6.0
@export var life : int = 10

var is_alive : bool :
	get:
		return life > 0


func _ready() -> void:
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reach_base)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_sell)
	UISignals.game_play_interface_loaded.connect(_on_game_play_interface_loaded)


func _on_enemy_reach_base(enemy : Enemy) -> void:
	life -= round(enemy.stats.get_stat_value(Utils.StatType.Damage))
	GameSignals.resource_change.emit(life, 1)
	print("player taking damage, life left: " , life)
	if life <= 0:
		lose()


func lose() -> void:
	GameSignals.lose_game.emit()


func _on_game_play_interface_loaded() -> void:
	GameSignals.resource_change.emit(gold, 0)
	GameSignals.resource_change.emit(life, 1)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	gold += enemy.stats.get_stat_value(Utils.StatType.Price)
	GameSignals.resource_change.emit(gold, 0)


func _on_building_placed(building : Building) -> void:
	gold -= building.stats.get_stat_value(Utils.StatType.Price)
	GameSignals.resource_change.emit(gold, 0)


func _on_building_sell(building : Building) -> void:
	gold += building.stats.get_stat_value(Utils.StatType.Price)
	GameSignals.resource_change.emit(gold, 0)
