class_name ResourceDisplayElement
extends PanelContainer


@onready var value_display : Label = $HBoxContainer/Value


func change_value(value : int) -> void:
	value_display.text = str(value)
