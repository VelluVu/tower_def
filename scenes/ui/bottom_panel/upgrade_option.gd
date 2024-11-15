class_name UpgradeOption
extends Panel


@onready var button : Button = $Button
@onready var label : Label = $Label

@export var index : int = 0
var building_data : BuildingData = null


func _ready() -> void:
	button.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	UISignals.upgrade_option_selected.emit(index, building_data.id)
