class_name PuffeDialogue
extends Control

#Puffe's portrait box: each of the level's PuffeLines plays once, when its trigger happens (queued while
#another line shows); an AfterPrevious line follows the line before it. A line waiting on something that
#never happens blocks nothing. Runs while paused (level-up cards) and never pauses the game itself.

const CHARACTERS_PER_SECOND : float = 45.0
const MIN_HOLD_TIME : float = 2.5
const HOLD_TIME_PER_CHARACTER : float = 0.05
const BETWEEN_LINES_DELAY : float = 0.4

@onready var box : PanelContainer = $MarginContainer/Box
@onready var text_label : Label = $MarginContainer/Box/HBoxContainer/Text

var lines : Array[PuffeLine] = []
#indexes into lines, waiting to be shown
var queue : Array[int] = []
#indexes already queued or shown, each line plays once
var used : Dictionary = {}
var current_index : int = -1
var is_typing : bool = false
var typed_characters : float = 0.0
var hold_left : float = 0.0
var delay_left : float = -1.0
var last_wave_number : int = 0
var is_mouse_on_box : bool = false


func _ready() -> void:
	box.visible = false
	box.gui_input.connect(_on_box_gui_input)
	box.mouse_entered.connect(_on_box_mouse_entered)
	box.mouse_exited.connect(_on_box_mouse_exited)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.wave_state_changed.connect(_on_wave_state_changed)
	GameSignals.wave_cleared.connect(_on_wave_cleared)
	GameSignals.gold_upgrade_bought.connect(_on_gold_upgrade_bought)
	GameSignals.upgrade_level_gained.connect(_on_upgrade_level_gained)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reached_end_point)

	var level : Level = Utils.game_control.scene_manager.current_level as Level
	if level != null and level.level_data != null:
		lines = level.level_data.puffe_lines

	_record(PuffeLine.Trigger.LevelStart)


func _process(delta : float) -> void:
	if delay_left >= 0.0:
		delay_left -= delta
		if delay_left < 0.0:
			_show_next_line()
		return

	if is_typing:
		typed_characters += delta * CHARACTERS_PER_SECOND
		text_label.visible_characters = int(typed_characters)
		if text_label.visible_characters >= text_label.get_total_character_count():
			_finish_typing()
	elif box.visible:
		hold_left -= delta
		if hold_left <= 0.0:
			_close_line()


func _record(trigger : PuffeLine.Trigger, wave_number : int = 0) -> void:
	for i in lines.size():
		var line : PuffeLine = lines[i]
		if used.has(i) or line.trigger != trigger:
			continue
		if line.wave_number != 0 and line.wave_number != wave_number:
			continue
		used[i] = true
		queue.append(i)
	_try_next_line()


func _try_next_line() -> void:
	if box.visible or delay_left >= 0.0 or queue.is_empty():
		return

	#the very first line shows at once, later ones after a short gap
	if current_index < 0:
		_show_next_line()
	else:
		delay_left = BETWEEN_LINES_DELAY


func _show_next_line() -> void:
	current_index = queue.pop_front()
	var line : PuffeLine = lines[current_index]
	text_label.text = line.text
	text_label.visible_characters = 0
	typed_characters = 0.0
	is_typing = true
	box.visible = true


func _finish_typing() -> void:
	is_typing = false
	text_label.visible_characters = -1
	hold_left = maxf(MIN_HOLD_TIME, text_label.get_total_character_count() * HOLD_TIME_PER_CHARACTER)


func _close_line() -> void:
	box.visible = false
	if is_mouse_on_box:
		_on_box_mouse_exited()

	var next : int = current_index + 1
	if next < lines.size() and not used.has(next) and lines[next].trigger == PuffeLine.Trigger.AfterPrevious:
		used[next] = true
		queue.push_front(next)
	_try_next_line()


#the first click shows the whole line, the second closes it
func _on_box_gui_input(event : InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	accept_event()
	if is_typing:
		_finish_typing()
	else:
		_close_line()


func _on_box_mouse_entered() -> void:
	is_mouse_on_box = true
	UISignals.mouse_on_gui.emit(true)


func _on_box_mouse_exited() -> void:
	is_mouse_on_box = false
	UISignals.mouse_on_gui.emit(false)


func _on_building_placed(_building : Building) -> void:
	_record(PuffeLine.Trigger.BuildingPlaced)


#wave_number is the number of waves started so far
func _on_wave_state_changed(wave_number : int, _wave_count : int, _can_start_next : bool, _early_start_bonus : float) -> void:
	while last_wave_number < wave_number:
		last_wave_number += 1
		_record(PuffeLine.Trigger.WaveStarted, last_wave_number)


func _on_wave_cleared(wave_number : int) -> void:
	_record(PuffeLine.Trigger.WaveCleared, wave_number)


func _on_gold_upgrade_bought(_building : Building, _is_evolve : bool) -> void:
	_record(PuffeLine.Trigger.GoldUpgradeBought)


func _on_upgrade_level_gained(_new_level : int, _cards : Array[UpgradeCard]) -> void:
	_record(PuffeLine.Trigger.LevelUp)


func _on_enemy_reached_end_point(_enemy : Enemy) -> void:
	_record(PuffeLine.Trigger.CastleHit)
