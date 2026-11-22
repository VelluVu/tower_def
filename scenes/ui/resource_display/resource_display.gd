class_name ResourceDisplay
extends Control


const UPGRADE_XP_TEXT : String = "Lv %d  %d / %d XP"
## GameSignals.resource_change index of the life counter (0 is gold).
const LIFE_INDEX : int = 1
const GOLD_INDEX : int = 0
## At this many lives or fewer the life counter keeps pulsing red.
const LOW_LIFE : int = 3

@onready var upgrade_xp_label : Label = %UpgradeXpLabel

var xp_bar : XpBar = null

@export var resource_display_elements : Array[ResourceDisplayElement]


func _ready() -> void:
	GameSignals.resource_change.connect(_resource_change)
	#along the bottom of the XP panel, under its text
	xp_bar = XpBar.new()
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	upgrade_xp_label.add_sibling(xp_bar)
	GameSignals.upgrade_xp_changed.connect(_on_upgrade_xp_changed)
	GameSignals.not_enough_gold.connect(_on_not_enough_gold)


#the gold counter blinks red, as the life counter does on a leak
func _on_not_enough_gold(_position : Vector2, _price : float) -> void:
	if GOLD_INDEX < resource_display_elements.size():
		resource_display_elements[GOLD_INDEX].flash()


func _on_upgrade_xp_changed(xp : float, xp_needed : float, upgrade_level : int) -> void:
	upgrade_xp_label.text = UPGRADE_XP_TEXT % [upgrade_level, xp, xp_needed]
	xp_bar.set_xp(xp, xp_needed, upgrade_level)


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
	if index == LIFE_INDEX:
		element.set_alarm(new_value > 0 and new_value <= LOW_LIFE)
