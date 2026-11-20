class_name ResourceDisplay
extends Control


const UPGRADE_XP_TEXT : String = "Lv %d  %d / %d XP"
## GameSignals.resource_change index of the life counter (0 is gold).
const LIFE_INDEX : int = 1

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
	
	var element : ResourceDisplayElement = resource_display_elements[index]
	#a level start sets life up from 0, only a drop is a leak
	var is_leak : bool = index == LIFE_INDEX and new_value < element.last_value
	element.change_value(new_value)
	if is_leak:
		element.flash()
