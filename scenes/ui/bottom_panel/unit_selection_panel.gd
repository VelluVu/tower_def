class_name UnitSelectionPanel
extends Panel


@onready var unit_info_grid_container : GridContainer = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer
@onready var unit_icon : TextureRect = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitIcon
@onready var name_value : Label = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField/Value
@onready var health_value : Label = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField2/Value
@onready var damage_value : Label = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField3/Value
@onready var price_value : Label = $BackgroundImage/HBoxContainer/InfoPanel/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField4/Value
@onready var sell_button : Button = $BackgroundImage/HBoxContainer/ButtonPanel/MarginContainer/SellButton
@onready var upgrade_panel : UpgradePanel = $BackgroundImage/HBoxContainer/UpgradePanel



func _ready():
	unit_info_grid_container.hide()
	unit_icon.hide()
	sell_button.hide()
	UISignals.selected_unit.connect(_on_unit_selected)
	UISignals.deselected_unit.connect(_on_unit_deselected)


func _on_unit_selected(unit_name : String, stats : Stats, icon : Texture2D, _is_building : bool = false, building_data : BuildingData = null):
	unit_info_grid_container.show()
	unit_icon.show()
	unit_icon.texture = icon
	name_value.text = unit_name
	health_value.text = str(stats.get_stat_value(Utils.StatType.Health)) + "/" + str(stats.get_stat_value(Utils.StatType.MaxHealth))
	damage_value.text = str(stats.get_stat_value(Utils.StatType.Damage))
	price_value.text = str(stats.get_stat_value(Utils.StatType.Price))
	
	if not _is_building:
		return

	sell_button.show()
	upgrade_panel.initialize_upgrade_options(building_data)



func _on_unit_deselected(_unit_name : String, _stats : Stats, _icon : Texture2D, _is_building : bool = false, _building_data : BuildingData = null):
	unit_icon.texture = null
	name_value.text = "jesus?"
	health_value.text = "0/0"
	damage_value.text = "0"
	price_value.text = "0"
	unit_info_grid_container.hide()
	unit_icon.hide()
	
	if not _is_building:
		return
	
	upgrade_panel.hide()
	sell_button.hide()


func _on_sell_button_pressed() -> void:
	UISignals.on_sell_selected_building_pressed.emit()
