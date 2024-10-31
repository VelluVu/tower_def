class_name RangeArea
extends Area2D

@export var draw_range : bool = true
var actor : Node2D :
	get:
		if actor == null:
			actor = get_parent()
		return actor


func _ready() -> void:
	GameSignals.deselected_unit.connect(_on_selected)
	GameSignals.selected_unit.connect(_on_selected)


func _on_selected(unit : Node2D) -> void:
	if unit != actor:
		return
		
	queue_redraw()


func _draw() -> void:
	if actor.selectable.is_selected:
		draw_circle(Vector2(0,0), actor.stats_manager.get_range_in_tiles(), Color.DARK_VIOLET, false)
