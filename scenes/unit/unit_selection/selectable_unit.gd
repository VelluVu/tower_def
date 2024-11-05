class_name SelectableUnit
extends Node


@onready var outline_shader_material : ShaderMaterial = ResourceLoader.load("res://assets/shaders/shader_materials/outline_shader_material.tres")

var is_selected : bool = false :
	set = _set_is_selected
var previous_material : Material = null
var original_material : Material = null

@export var actor : Node2D :
	get:
		if actor == null:
			actor = get_parent()
		return actor

@export var sprite : AnimatedSprite2D :
	get:
		if sprite == null:
			for sibling in actor.get_children():
				if sibling is AnimatedSprite2D:
					sprite = sibling
		return sprite


func change_material(_material : Material) -> void:
	if _material == null:
		sprite.material = original_material
		return
	
	previous_material = sprite.material
	sprite.material = _material


func _ready() -> void:
	if not actor.is_in_group(GroupNames.SELECTABLE):
		actor.add_to_group(GroupNames.SELECTABLE)
		
	previous_material = sprite.material
	original_material = sprite.material
	GameSignals.selected_unit.connect(_on_selected_unit)
	GameSignals.deselected_unit.connect(_on_deselected_unit)


func _on_selected_unit(unit : Node2D) -> void:
	if unit != actor:
		return
		
	is_selected = true


func _on_deselected_unit(unit : Node2D) -> void:
	if unit != actor:
		return
	
	is_selected = false


func _set_is_selected(value : bool) -> void:
	if value == is_selected:
		return
	
	is_selected = value
	
	if is_selected:
		change_material(outline_shader_material)
		var is_building : bool = actor.is_in_group(GroupNames.BUILDINGS)
		UISignals.selected_unit.emit(actor.name, actor.stats, actor.icon, is_building)
		
		if is_building:
			if not actor.is_placed:
				return
		
		if not actor.stats.stats_changed.is_connected(_on_selected_data_change):
			actor.stats.stats_changed.connect(_on_selected_data_change)
	else:
		change_material(null)
		UISignals.deselected_unit.emit(actor.name, actor.stats, actor.icon, actor.is_in_group(GroupNames.BUILDINGS))
		if actor.stats.stats_changed.is_connected(_on_selected_data_change):
			actor.stats.stats_changed.disconnect(_on_selected_data_change)


func _on_selected_data_change() -> void:
	UISignals.selected_unit.emit(actor.name, actor.stats, actor.icon, actor.is_in_group(GroupNames.BUILDINGS))
