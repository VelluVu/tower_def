class_name SpeedControlPanel
extends Control


@onready var speed_value : Label = $MarginContainer/Panel/MarginContainer/HBoxContainer/SpeedInfo/Value


func _ready() -> void:
	speed_value.text = str(Utils.game_control.time_scale)
	GameSignals.time_scale_change.connect(_on_time_scale_change)


func _on_slower_pressed() -> void:
	UISignals.slower_speed_pressed.emit()


func _on_faster_pressed() -> void:
	UISignals.faster_speed_pressed.emit()


func _on_time_scale_change(new_scale : float) -> void:
	speed_value.text = str(new_scale)
