class_name Tiles
extends Node2D


@onready var front_layer : TileMapLayer = $FrontTileMapLayer
@onready var water_layer : TileMapLayer = $WaterTileMapLayer
@onready var ground_layer : TileMapLayer = $GroundTileMapLayer
@onready var background_layer : TileMapLayer = $BackgroundTileMapLayer

var tile_map_layers : Array[TileMapLayer]

var background_pixel_size : Vector2 :
	get:
		var bg_rect_size : Vector2 = background_layer.get_used_rect().size
		return Vector2(bg_rect_size.x * Utils.TILE_SIZE * 0.5, bg_rect_size.y * Utils.TILE_SIZE * 0.5)


func _ready() -> void:
	for child in get_children():
		if child is TileMapLayer:
			tile_map_layers.append(child)
