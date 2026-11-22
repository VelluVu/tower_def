class_name SpeedControlPanel
extends Control


const SLOWER_TOOLTIP : String = "Slower  [%s]"
const FASTER_TOOLTIP : String = "Faster  [%s]"
## "×1", "×1.5": reads as a speed, not a stray number.
const SPEED_FORMAT : String = "×%s"

@onready var speed_value : Label = $MarginContainer/Panel/MarginContainer/HBoxContainer/SpeedInfo/Value
@onready var slower_button : Button = $MarginContainer/Panel/MarginContainer/HBoxContainer/Slower
@onready var faster_button : Button = $MarginContainer/Panel/MarginContainer/HBoxContainer/Faster


func _ready() -> void:
	speed_value.text = format_speed(Utils.game_control.time_scale)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	InputManager.shortcut_pressed.connect(_on_shortcut_pressed)
	InputManager.bindings_changed.connect(_update_tooltips)
	_update_tooltips()


func _update_tooltips() -> void:
	slower_button.tooltip_text = SLOWER_TOOLTIP % InputManager.get_binding_text(InputManager.ACTION_SPEED_DOWN)
	faster_button.tooltip_text = FASTER_TOOLTIP % InputManager.get_binding_text(InputManager.ACTION_SPEED_UP)


func _on_shortcut_pressed(action : StringName) -> void:
	if action == InputManager.ACTION_SPEED_DOWN:
		_on_slower_pressed()
	elif action == InputManager.ACTION_SPEED_UP:
		_on_faster_pressed()


func _on_slower_pressed() -> void:
	UISignals.slower_speed_pressed.emit()


func _on_faster_pressed() -> void:
	UISignals.faster_speed_pressed.emit()


func _on_time_scale_change(new_scale : float) -> void:
	speed_value.text = format_speed(new_scale)


static func format_speed(scale : float) -> String:
	var text : String = String.num(scale, 2)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return SPEED_FORMAT % text
