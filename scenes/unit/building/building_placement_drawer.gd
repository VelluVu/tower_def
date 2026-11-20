extends Node2D

## A new building flashes mint, the "pop" of it going up (a hit flashes white).
const PLACED_FLASH_COLOR : Color = Color("68ffd0")
const PLACED_FLASH_SECONDS : float = 0.2
#Puffe's mint for a free spot, Endesga 32 red for a blocked one (the building hides there, so the red is stronger)
const VALID_COLOR : Color = Color("68ffd0", 0.4)
const INVALID_COLOR : Color = Color("e43b44", 0.65)

var is_draw : bool = false
var is_valid : bool = false
var draw_rectangle : Rect2


func draw_building(rect : Rect2, rect_position : Vector2, _is_valid : bool, _is_draw : bool) -> void:
	self.is_draw = _is_draw
	self.is_valid = _is_valid
	draw_rectangle = rect
	draw_rectangle.position = (draw_rectangle.position + rect_position)
	queue_redraw()


func _ready() -> void:
	z_index = 1
	GameSignals.building_placed.connect(_on_building_placed)


func _on_building_placed(building : Building) -> void:
	if building.animation_control != null:
		building.animation_control.play_flash(PLACED_FLASH_COLOR, PLACED_FLASH_SECONDS)


func _draw() -> void:
	if not is_draw:
		return
	
	draw_rect(draw_rectangle, VALID_COLOR if is_valid else INVALID_COLOR)
