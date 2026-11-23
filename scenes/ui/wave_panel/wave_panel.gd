class_name WavePanel
extends Control


const WAVE_TEXT : String = "Wave %d/%d"
const ENDLESS_WAVE_TEXT : String = "Wave %d"
const START_WAVE_TEXT : String = "Start wave"
const EARLY_START_TEXT : String = "Next +%d gold"
const START_WAVE_TOOLTIP : String = "Start wave  [%s]
Sends the next wave."
const EARLY_START_TOOLTIP : String = "Early start  [%s]
Sends the next wave now, while this one is still out. Pays %d bonus gold."

@onready var wave_value : Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/WaveValue
@onready var start_wave_button : Button = $MarginContainer/Panel/MarginContainer/VBoxContainer/StartWaveButton
@onready var wave_box : VBoxContainer = $MarginContainer/Panel/MarginContainer/VBoxContainer
@onready var panel : Panel = $MarginContainer/Panel
@onready var panel_margin : MarginContainer = $MarginContainer/Panel/MarginContainer

var preview : WavePreview = null
#the scene's panel height, before the preview row grew it
var base_panel_height : float = -1.0


func _ready() -> void:
	GameSignals.wave_state_changed.connect(_on_wave_state_changed)
	add_child(WaveBanner.new())
	preview = WavePreview.new()
	wave_box.add_child(preview)
	preview.hide()
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

	var next_wave : WaveData = get_next_wave() if start_wave_button.visible else null
	preview.show_wave(next_wave)
	_fit_panel.call_deferred()
	if next_wave != null:
		start_wave_button.tooltip_text += "
" + WavePreview.describe(next_wave)


## A Panel does not grow with its content: fit its height to the preview row (deferred, so the new entries have their size).
func _fit_panel() -> void:
	if base_panel_height < 0.0:
		base_panel_height = panel.custom_minimum_size.y
	panel.custom_minimum_size.y = maxf(base_panel_height, panel_margin.get_combined_minimum_size().y)


## The wave the button sends; in Survival the grown copy the runner will make.
static func get_next_wave() -> WaveData:
	var manager : Object = Utils.game_control.get(&"scene_manager") if Utils.game_control != null else null
	#untyped and checked first: a level freed under the manager would be a script error in a typed variable
	var level : Variant = manager.get(&"current_level") if manager != null else null
	if not is_instance_valid(level) or not level is Level or level.wave_runner == null:
		return null
	var runner : WaveRunner = level.wave_runner
	if runner.is_endless:
		return SurvivalRules.make_wave(runner.waves, runner.wave_number + 1) if not runner.waves.is_empty() else null
	return runner.next_wave
