class_name UnitSelectionPanel
extends Panel


@onready var unit_info_grid_container : GridContainer = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer
@onready var unit_icon : TextureRect = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitIcon
@onready var name_value : Label = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer/Name/Value
@onready var sell_button : Button = $BackgroundImage/HBoxContainer/ButtonPanel/MarginContainer/SellButton
@onready var upgrade_panel : UpgradePanel = $BackgroundImage/HBoxContainer/UpgradePanel

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
	unit_info_grid_container.hide()
	unit_icon.hide()
	sell_button.hide()
	UISignals.selected_unit.connect(_on_unit_selected)
	UISignals.deselected_unit.connect(_on_unit_deselected)


func _on_unit_selected(unit_name : String, actor_stats : Stats, main_skill : Skill, icon : Texture2D, _is_building : bool = false):
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


func _on_sell_button_pressed() -> void:
	UISignals.on_sell_selected_building_pressed.emit()
