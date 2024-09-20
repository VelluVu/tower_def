class_name UnitSelectionPanel
extends MarginContainer


@onready var unit_info_grid_container : GridContainer = $BackgroundImage/MarginContainer/HBoxContainer/UnitInfoGridContainer
@onready var unit_icon : TextureRect = $BackgroundImage/MarginContainer/HBoxContainer/TextureRect
@onready var name_value : Label = $BackgroundImage/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField/Value
@onready var health_value : Label = $BackgroundImage/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField2/Value
@onready var damage_value : Label = $BackgroundImage/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField3/Value
@onready var price_value : Label = $BackgroundImage/MarginContainer/HBoxContainer/UnitInfoGridContainer/InfoField4/Value


func _ready():
	unit_info_grid_container.hide()
	unit_icon.hide()
	UISignals.selected_unit.connect(_on_unit_selected)
	UISignals.deselected_unit.connect(_on_unit_deselected)


func _on_unit_selected(unit_name : String, stats : Stats, icon : Texture2D):
	unit_info_grid_container.show()
	unit_icon.show()
	unit_icon.texture = icon
	name_value.text = unit_name
	health_value.text = str(stats.health) + "/" + str(stats.max_health)
	damage_value.text = str(stats.damage)
	price_value.text = str(stats.price)


func _on_unit_deselected(_unit_name : String, _stats : Stats, _icon : Texture2D):
	unit_icon.texture = null
	name_value.text = "jesus?"
	health_value.text = "0/0"
	damage_value.text = "0"
	price_value.text = "0"
	unit_info_grid_container.hide()
	unit_icon.hide()
