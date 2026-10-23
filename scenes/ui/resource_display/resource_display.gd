class_name ResourceDisplay
extends Control


const UPGRADE_XP_TEXT : String = "Lv %d  %d / %d XP"

@onready var upgrade_xp_label : Label = %UpgradeXpLabel

@export var resource_display_elements : Array[ResourceDisplayElement]


func _ready() -> void:
	GameSignals.resource_change.connect(_resource_change)
	GameSignals.upgrade_xp_changed.connect(_on_upgrade_xp_changed)


func _on_upgrade_xp_changed(xp : float, xp_needed : float, upgrade_level : int) -> void:
	upgrade_xp_label.text = UPGRADE_XP_TEXT % [upgrade_level, xp, xp_needed]


func _resource_change(new_value : int, index : int) -> void:
	if index >= resource_display_elements.size():
		push_warning(name ," resource index " , index , " is out of bounds")
		return
	
	resource_display_elements[index].change_value(new_value)
