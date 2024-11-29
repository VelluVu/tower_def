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


func _data_change() -> void:
	_signal_data_for_selection_panel(is_selected)


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
		#for sell button
		var is_building : bool = actor.is_in_group(GroupNames.BUILDINGS)
		
		if is_building:
			if not actor.is_placed:
				UISignals.selected_unit.emit(actor.name, actor.stats, actor.skill, actor.icon)
				return
		
		if not actor.stats.stats_changed.is_connected(_on_selected_data_change):
			actor.stats.stats_changed.connect(_on_selected_data_change)
		
		if not actor.stats_changed.is_connected(_data_change):
			actor.stats_changed.connect(_data_change)
	else:
		
		if actor.stats.stats_changed.is_connected(_on_selected_data_change):
			actor.stats.stats_changed.disconnect(_on_selected_data_change)
		
		if actor.stats_changed.is_connected(_data_change):
			actor.stats_changed.disconnect(_data_change)
	
	change_material(null if not is_selected else outline_shader_material)
	#get the upgrade data if there is any for starter element choices!
	_signal_data_for_selection_panel(is_selected)
	actor.selected.emit(is_selected)


func _on_selected_data_change() -> void:
	#get the upgrade data if there is any for starter element choices!
	_signal_data_for_selection_panel(is_selected)


func _signal_data_for_selection_panel(_is_selected : bool) -> void:
	var is_building : bool = actor.is_in_group(GroupNames.BUILDINGS)
	
	if is_building: 
		if _is_selected:
			UISignals.selected_unit.emit(actor.name, actor.stats, actor.skill, actor.icon, is_building)
			UISignals.upgrade_options_change.emit(actor._get_building_data())
		else:
			UISignals.deselected_unit.emit()
			UISignals.upgrade_options_change.emit(null)
	else:
		if _is_selected:
			UISignals.selected_unit.emit(actor.name, actor.stats, actor.skill, actor.icon)
		else:
			UISignals.deselected_unit.emit()
