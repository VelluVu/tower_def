class_name RangeArea
extends Area2D

@export var draw_range : bool = true
var actor : Node2D :
	get:
		if actor == null:
			actor = get_parent()
		return actor


func _ready() -> void:
	actor.selected.connect(_on_selected)


func _on_selected(_value : bool) -> void:
	queue_redraw()


func _draw() -> void:
	if not actor.is_placed or actor.is_selected:
		draw_circle(Vector2(0,0), actor.stats_manager.get_range_in_tiles(), Color.DARK_VIOLET, false)
