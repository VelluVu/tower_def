class_name Level
extends Node2D

@onready var tile_map : TileMapLayer = $TileMapLayer
@onready var navigation_region : NavigationRegion2D = $NavigationRegion2D
@onready var end_point : Marker2D = $EndPoint


func _ready() -> void:
	GameStateSignals.level_loaded.emit(self)


func _exit_tree() -> void:
	GameStateSignals.game_stop.emit()
