class_name UpgradePanel
extends Panel


@onready var upgrade_container : HBoxContainer = $MarginContainer/UpgradeOptionContainer
var building_data : BuildingData = null


func _ready() -> void:
	UISignals.upgrade_options_change.connect(_on_upgrade_options_change)
	_on_upgrade_options_change(null)


func _on_upgrade_options_change(_building_data : BuildingData) -> void:
	change_upgrade_options(_building_data)


func change_upgrade_options(_building_data : BuildingData) -> void:
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
		child.building_data = _building_data
		index += 1
