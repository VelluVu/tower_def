class_name BuildingOption
extends Panel


## The price in the slot's corner (polish, 2026-11-22): coin gold while it can be paid, red while not.
const PRICE_FORMAT : String = "%d"
const AFFORDABLE_COLOR : Color = Color("feae34")
const TOO_DEAR_COLOR : Color = Color("e43b44")
const FONT_COLOR : StringName = &"font_color"
## Nudged into the corner: the label's line box is taller than its digits, and the tray's
## scroll container clips anything past the slot's edge.
const PRICE_OVERHANG : Vector2 = Vector2(1, 2)
## GameSignals.resource_change index of gold.
const GOLD_INDEX : int = 0

@onready var button : Button = $SelectBuildingButton

var building_index : int = 0
var price : float = -1.0
var gold : float = 0.0
var price_label : Label = null

signal is_activated(is_activated : bool, option : BuildingOption)


func _ready() -> void:
	GameSignals.building_placement_change.connect(_on_building_placement_change)
	UISignals.focus_building_option.connect(_focus_building_changed)
	UISignals.building_option_updated.connect(_on_building_option_updated)
	UISignals.building_option_tooltip.connect(_on_building_option_tooltip)
	UISignals.building_option_price.connect(_on_building_option_price)
	GameSignals.resource_change.connect(_on_resource_change)
	price_label = Label.new()
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.hide()
	button.add_child(price_label)
	#grows up and left from the corner, whatever the number's width
	price_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	price_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	price_label.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _on_building_option_price(_building_index : int, new_price : float) -> void:
	if building_index != _building_index:
		return
	price = new_price
	price_label.text = PRICE_FORMAT % ceili(price)
	price_label.offset_right = PRICE_OVERHANG.x
	price_label.offset_bottom = PRICE_OVERHANG.y
	price_label.offset_left = PRICE_OVERHANG.x
	price_label.offset_top = PRICE_OVERHANG.y
	price_label.show()
	_update_price_color()


func _on_resource_change(value : int, index : int) -> void:
	if index != GOLD_INDEX:
		return
	gold = value
	_update_price_color()


func _update_price_color() -> void:
	var can_pay : bool = GameSignals.free_build or gold >= price
	price_label.add_theme_color_override(FONT_COLOR, AFFORDABLE_COLOR if can_pay else TOO_DEAR_COLOR)


func _on_building_option_tooltip(_building_index : int, text : String) -> void:
	if building_index == _building_index:
		button.tooltip_text = text


func _on_building_placement_change(is_placing : bool) -> void:
	if not is_placing:
		if button.button_pressed:
			button.button_pressed = false


func _focus_building_changed(index : int) -> void:
	if index < 0:
		if button.button_pressed:
			button.button_pressed = false
	if index == building_index:
		button.button_pressed = true


func _on_select_building_button_pressed() -> void:
	is_activated.emit(button.button_pressed, self)
	UISignals.building_option_selected.emit(building_index)


func _on_building_option_updated(_building_index : int, _icon : Texture2D) -> void:
	if building_index != _building_index:
		return
		
	button.icon = _icon
