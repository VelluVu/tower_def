class_name UpgradePanel
extends Panel


@onready var upgrade_container : HBoxContainer = $MarginContainer/UpgradeOptionContainer
var building_data : BuildingData = null


func _ready() -> void:
	hide()


func initialize_upgrade_options(_building_data : BuildingData) -> void:
	if _building_data == null:
		hide()
		return
	
	building_data = _building_data
	var index : int = 0
	show()
		
	for child in upgrade_container.get_children():
		child.index = index
		
		if index >= building_data.upgrade_option_icons.size():
			child.hide()
			index += 1
			continue
		
		child.show()
		child.button.icon = building_data.upgrade_option_icons[index]
		child.label.text = building_data.upgrade_option_infos[index]
		child.building_data = _building_data
		index += 1
