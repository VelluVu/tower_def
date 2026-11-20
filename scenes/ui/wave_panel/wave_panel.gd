class_name WavePanel
extends Control


const WAVE_TEXT : String = "Wave %d/%d"
const ENDLESS_WAVE_TEXT : String = "Wave %d"
const START_WAVE_TEXT : String = "Start wave"
const EARLY_START_TEXT : String = "Next +%d gold"
const START_WAVE_TOOLTIP : String = "Sends the next wave  [%s]"
const EARLY_START_TOOLTIP : String = "Sends the next wave now, while this one is still out  [%s]
An early start pays %d bonus gold."

@onready var wave_value : Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/WaveValue
@onready var start_wave_button : Button = $MarginContainer/Panel/MarginContainer/VBoxContainer/StartWaveButton


func _ready() -> void:
	GameSignals.wave_state_changed.connect(_on_wave_state_changed)
	add_child(WaveBanner.new())
	InputManager.shortcut_pressed.connect(_on_shortcut_pressed)


func _on_shortcut_pressed(action : StringName) -> void:
	#the same rules as the button: only while it shows and can start a wave
	if action == InputManager.ACTION_START_WAVE and start_wave_button.visible and not start_wave_button.disabled:
		_on_start_wave_pressed()


func _on_start_wave_pressed() -> void:
	UISignals.start_wave_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)


func _on_wave_state_changed(wave_number : int, wave_count : int, can_start_next : bool, early_start_bonus : float) -> void:
	#a wave count of 0: Survival, the waves never end
	var is_endless : bool = wave_count <= 0
	wave_value.text = ENDLESS_WAVE_TEXT % wave_number if is_endless else WAVE_TEXT % [wave_number, wave_count]
	start_wave_button.visible = is_endless or wave_number < wave_count
	start_wave_button.disabled = not can_start_next
	start_wave_button.text = EARLY_START_TEXT % early_start_bonus if early_start_bonus > 0.0 else START_WAVE_TEXT
	var key : String = InputManager.get_binding_text(InputManager.ACTION_START_WAVE)
	start_wave_button.tooltip_text = EARLY_START_TOOLTIP % [key, early_start_bonus] if early_start_bonus > 0.0 else START_WAVE_TOOLTIP % key
