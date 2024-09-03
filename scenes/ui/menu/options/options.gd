class_name Options
extends Control


func _on_graphics_pressed() -> void:
	#activate graphics tab deactivate other tabs
	pass # Replace with function body.


func _on_audio_pressed() -> void:
	#activate audio tab deactivate other tabs
	pass # Replace with function body.


func _on_back_pressed() -> void:
	MenuSignals.to_main_menu.emit()
