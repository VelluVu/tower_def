class_name UnitSelectionPanel
extends PanelContainer

## A small card fixed to the bottom-left corner: icon, name, the stats in two short lines,
## then the gold upgrades and Sell. Fixed width and a fixed corner, so it never moves.

const UPGRADE_BUTTON_TEXT : String = "%s
%dg"
const EVOLVE_BUTTON_TEXT : String = "%dg"
#fixed width, long titles end in "..." and the tooltip has the full one
const UPGRADE_BUTTON_MIN_SIZE : Vector2 = Vector2(50, 0)
const EVOLVE_BUTTON_MIN_SIZE : Vector2 = Vector2(24, 0)
const UPGRADE_BUTTON_ICON_SIZE : int = 12
const UPGRADE_BUTTON_FONT_SIZE : int = 8
## Space between the card and the window's bottom-left corner.
const CORNER_MARGIN : float = 4.0

@onready var unit_info_grid_container : GridContainer = $HBoxContainer/InfoBox/UnitInfoGridContainer
@onready var unit_icon : TextureRect = $HBoxContainer/UnitIcon
@onready var name_value : Label = $HBoxContainer/InfoBox/NameLabel
@onready var sell_button : Button = $HBoxContainer/InfoBox/ButtonRow/SellButton
@onready var upgrade_option_container : HBoxContainer = $HBoxContainer/InfoBox/ButtonRow/UpgradeOptionContainer
@onready var button_row : HBoxContainer = $HBoxContainer/InfoBox/ButtonRow

var horizontal_stat_fields : Array[HorizontalStatField] :
	get:
		if not horizontal_stat_fields.is_empty():
			return horizontal_stat_fields
		for child in unit_info_grid_container.get_children():
			if child is HorizontalStatField:
				horizontal_stat_fields.append(child)
		return horizontal_stat_fields

var listed_stat_enums : Array[Utils.StatType] = [
	Utils.StatType.Health, 
	Utils.StatType.Damage, 
	Utils.StatType.AttackSpeed, 
	#also shows the critical multiplier
	Utils.StatType.CriticalChance,
	Utils.StatType.AttackRange,
	Utils.StatType.Price]


func _ready() -> void:
	hide()
	unit_info_grid_container.hide()
	unit_icon.hide()
	sell_button.hide()
	button_row.hide()
	UISignals.selected_unit.connect(_on_unit_selected)
	UISignals.deselected_unit.connect(_on_unit_deselected)
	UISignals.gold_upgrades_changed.connect(_on_gold_upgrades_changed)


func _on_unit_selected(unit_name : String, actor_stats : Stats, main_skill : Skill, icon : Texture2D, _is_building : bool = false) -> void:
	show()
	unit_info_grid_container.show()
	unit_icon.show()
	unit_icon.texture = icon
	name_value.text = unit_name
	
	var index : int = 0
	for field in horizontal_stat_fields:
		field.set_field(listed_stat_enums[index],actor_stats, main_skill)
		index += 1
		
	sell_button.visible = _is_building
	_update_button_row()


func _on_unit_deselected() -> void:
	unit_icon.texture = null
	name_value.text = "jesus?"
	#nulls the stat fields
	for field in horizontal_stat_fields:
		field.set_field()
	unit_info_grid_container.hide()
	unit_icon.hide()
	sell_button.visible = false
	hide()


func _on_sell_button_pressed() -> void:
	UISignals.on_sell_selected_building_pressed.emit()


func _on_gold_upgrades_changed(options : Array[GoldUpgradeOption]) -> void:
	for child in upgrade_option_container.get_children():
		upgrade_option_container.remove_child(child)
		child.queue_free()
	
	for index in options.size():
		upgrade_option_container.add_child(_create_upgrade_button(options[index], index))

	_update_button_row()


func _update_button_row() -> void:
	button_row.visible = sell_button.visible or upgrade_option_container.get_child_count() > 0
	_fit_to_corner.call_deferred()


## Shrinks to the content and keeps the bottom-left corner in place; resizing alone keeps
## the top edge, so a shorter card would float up. Deferred so new buttons have their size.
func _fit_to_corner() -> void:
	reset_size()
	position.y = get_parent_area_size().y - size.y - CORNER_MARGIN


func _create_upgrade_button(option : GoldUpgradeOption, index : int) -> Button:
	var button : Button = Button.new()
	button.theme = sell_button.theme
	button.custom_minimum_size = EVOLVE_BUTTON_MIN_SIZE if option.icon != null else UPGRADE_BUTTON_MIN_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", UPGRADE_BUTTON_FONT_SIZE)
	button.add_theme_constant_override("icon_max_width", UPGRADE_BUTTON_ICON_SIZE)
	button.icon = option.icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.text = EVOLVE_BUTTON_TEXT % option.cost if option.icon != null else UPGRADE_BUTTON_TEXT % [option.title, option.cost]
	button.tooltip_text = option.title
	button.disabled = not option.is_affordable
	button.pressed.connect(_on_upgrade_button_pressed.bind(index))
	return button


func _on_upgrade_button_pressed(index : int) -> void:
	UISignals.gold_upgrade_pressed.emit(index)
