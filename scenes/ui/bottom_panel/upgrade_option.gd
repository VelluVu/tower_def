class_name UpgradeOption
extends Panel


@onready var button : Button = $Button
@onready var label : Label = $Label

@export var index : int = 0
var building_data : BuildingData = null :
	set = _set_building_data


func _ready() -> void:
	button.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	UISignals.upgrade_option_selected.emit(index, building_data.id)


func _set_building_data(new_data : BuildingData) -> void:
	building_data = new_data
	button.icon = building_data.upgrade_option_icons[index]
	label.text = building_data.upgrade_option_infos[index]
	
	if building_data.random_upgrade_resource.is_empty():
		return
	
	if building_data.random_upgrade_resource[index] == null:
		return
	
	var random_upgrade_resource : EvolveResource = building_data.random_upgrade_resource[index]
	
	if random_upgrade_resource.is_percent:
		label.text = label.text + " " + str(random_upgrade_resource.modify_value * 100) + "%"
	else:
		label.text = label.text + " " + str(random_upgrade_resource.modify_value)
