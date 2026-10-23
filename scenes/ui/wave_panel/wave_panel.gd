class_name WavePanel
extends Control


const WAVE_TEXT : String = "Wave %d/%d"
const START_WAVE_TEXT : String = "Start wave"
const EARLY_START_TEXT : String = "Next +%d gold"

@onready var wave_value : Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/WaveValue
@onready var start_wave_button : Button = $MarginContainer/Panel/MarginContainer/VBoxContainer/StartWaveButton


func _ready() -> void:
	GameSignals.wave_state_changed.connect(_on_wave_state_changed)


func _on_start_wave_pressed() -> void:
	UISignals.start_wave_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)


func _on_wave_state_changed(wave_number : int, wave_count : int, can_start_next : bool, early_start_bonus : float) -> void:
	wave_value.text = WAVE_TEXT % [wave_number, wave_count]
	start_wave_button.visible = wave_number < wave_count
	start_wave_button.disabled = not can_start_next
	start_wave_button.text = EARLY_START_TEXT % early_start_bonus if early_start_bonus > 0.0 else START_WAVE_TEXT
