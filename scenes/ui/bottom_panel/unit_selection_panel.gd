class_name UnitSelectionPanel
extends Panel


const UPGRADE_BUTTON_TEXT : String = "%s
%dg"
const EVOLVE_BUTTON_TEXT : String = "%dg"
const UPGRADE_BUTTON_MIN_SIZE : Vector2 = Vector2(36, 0)
const UPGRADE_BUTTON_ICON_SIZE : int = 16
const UPGRADE_BUTTON_FONT_SIZE : int = 8

@onready var unit_info_grid_container : GridContainer = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer
@onready var unit_icon : TextureRect = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitIcon
@onready var name_value : Label = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer/Name/Value
@onready var sell_button : Button = $BackgroundImage/HBoxContainer/ButtonPanel/MarginContainer/SellButton
@onready var upgrade_panel : Panel = $BackgroundImage/HBoxContainer/UpgradePanel
@onready var upgrade_option_container : HBoxContainer = $BackgroundImage/HBoxContainer/UpgradePanel/MarginContainer/UpgradeOptionContainer

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
	Utils.StatType.CriticalChance, 
	Utils.StatType.CriticalMultiplier, 
	Utils.StatType.AttackRange, 
	Utils.StatType.Price]


func _ready():
	hide()
	unit_info_grid_container.hide()
	unit_icon.hide()
	sell_button.hide()
	upgrade_panel.hide()
	UISignals.selected_unit.connect(_on_unit_selected)
	UISignals.deselected_unit.connect(_on_unit_deselected)
	UISignals.gold_upgrades_changed.connect(_on_gold_upgrades_changed)


func _on_unit_selected(unit_name : String, actor_stats : Stats, main_skill : Skill, icon : Texture2D, _is_building : bool = false):
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


func _on_unit_deselected():
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
	
	upgrade_panel.visible = not options.is_empty()
	
	for index in options.size():
		upgrade_option_container.add_child(_create_upgrade_button(options[index], index))


func _create_upgrade_button(option : GoldUpgradeOption, index : int) -> Button:
	var button : Button = Button.new()
	button.theme = sell_button.theme
	button.custom_minimum_size = UPGRADE_BUTTON_MIN_SIZE
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
