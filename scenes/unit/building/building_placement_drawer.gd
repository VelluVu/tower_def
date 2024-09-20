extends Node2D


var is_draw : bool = false
var is_valid : bool = false
var draw_rectangle : Rect2


func draw_building(rect : Rect2, rect_position : Vector2, _is_valid : bool, _is_draw : bool) -> void:
	self.is_draw = _is_draw
	self.is_valid = _is_valid
	draw_rectangle = rect
	draw_rectangle.position = (draw_rectangle.position + rect_position)
	queue_redraw()


func _ready():
	z_index = 1


func _draw():
	if not is_draw:
		return
	
	if is_valid:		
		draw_rect(draw_rectangle, Color(0,1,0,0.4))
	else:
		draw_rect(draw_rectangle, Color(1,0,0,0.4))
