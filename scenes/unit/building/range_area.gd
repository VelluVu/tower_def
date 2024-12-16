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


func _on_stats_changed() -> void:
	queue_redraw()


func _on_selected(is_selected : bool) -> void:
	queue_redraw()
	
	if not is_selected:
		if actor.stats_changed.is_connected(_on_stats_changed):
			actor.stats_changed.disconnect(_on_stats_changed)
		return
	
	if not actor.stats_changed.is_connected(_on_stats_changed):
		actor.stats_changed.connect(_on_stats_changed)
	


func _draw() -> void:
	if actor.selectable.is_selected:
		draw_circle(Vector2(0,0), actor.radius, Color.DARK_VIOLET, false)
