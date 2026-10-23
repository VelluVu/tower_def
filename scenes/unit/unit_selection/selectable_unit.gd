class_name SelectableUnit
extends Node


const OUTLINE_PARAMETER : StringName = &"outline_enabled"

var is_selected : bool = false :
	set = _set_is_selected

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

## The name shown when selected; empty falls back to the scene file name.
@export var display_name : String = ""


#the outline is a toggle on the unit's own sprite material (unit_sprite.gdshader), so the hit flash keeps working while selected
func show_outline(is_shown : bool) -> void:
	var shader_material : ShaderMaterial = sprite.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(OUTLINE_PARAMETER, is_shown)


## Call after the actor swaps its sprite (an element evolve), so the outline follows the new one.
func set_sprite(new_sprite : AnimatedSprite2D) -> void:
	sprite = new_sprite
	show_outline(is_selected)


func _data_change() -> void:
	_signal_data_for_selection_panel(is_selected)


func _ready() -> void:
	if not actor.is_in_group(GroupNames.SELECTABLE):
		actor.add_to_group(GroupNames.SELECTABLE)
		
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
				UISignals.selected_unit.emit(_get_display_name(), actor.stats, actor.skill, actor.icon)
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
	
	show_outline(is_selected)
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
			UISignals.selected_unit.emit(_get_display_name(), actor.stats, actor.skill, actor.icon, is_building)
		else:
			UISignals.deselected_unit.emit()
	else:
		if _is_selected:
			UISignals.selected_unit.emit(_get_display_name(), actor.stats, actor.skill, actor.icon)
		else:
			UISignals.deselected_unit.emit()


#the node name carries a placement counter (PuffeBolter00, 01, ...); the scene file is stable
func _get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if actor.scene_file_path.is_empty():
		return actor.name
	return actor.scene_file_path.get_file().get_basename().capitalize()
