class_name Tiles
extends Node2D


var tile_map_layers : Array[TileMapLayer]
@onready var object_layer : TileMapLayer = $ObjectTileMapLayer
@onready var water_layer : TileMapLayer = $WaterTileMapLayer
@onready var ground_layer : TileMapLayer = $GroundTileMapLayer
@onready var background_layer : TileMapLayer = $BackgroundTileMapLayer


func _ready() -> void:
	for child in get_children():
		if child is TileMapLayer:
			tile_map_layers.append(child)
