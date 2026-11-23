class_name PauseMenu
extends Control

## Over the buttons (polish, 2026-11-22): the level's name and wave, and the talent point
## conditions as they stand now (the win screen's checklist), so a pause shows what is still in reach.
const WAVE_FORMAT : String = "Wave %d/%d"
const ENDLESS_WAVE_FORMAT : String = "Wave %d"
const SO_FAR_TEXT : String = "Points so far"
const SUBTITLE_COLOR : Color = Color("8b9bb4")
const GAP : float = 4.0

@onready var title_label : Label = $MarginContainer/VBoxContainer/TitleLabel


func _ready() -> void:
	var manager : Object = Utils.game_control.get(&"scene_manager") if Utils.game_control != null else null
	var level : Level = manager.get(&"current_level") as Level if manager != null else null
	if level == null or not is_instance_valid(level):
		return
	var lines : Array[Control] = []
	var info : Label = Label.new()
	var level_name : String = level.level_data.level_name if level.level_data != null and not level.level_data.level_name.is_empty() else ""
	var runner : WaveRunner = level.wave_runner
	#before the first wave the player is building for wave 1, not on a "wave 0"
	var shown_wave : int = maxi(runner.wave_number, 1)
	var wave_text : String = ENDLESS_WAVE_FORMAT % shown_wave if runner.wave_count <= 0 else WAVE_FORMAT % [shown_wave, runner.wave_count]
	info.text = "%s  %s" % [level_name, wave_text] if not level_name.is_empty() else wave_text
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.append(info)
	#Survival earns its points by waves, not by these
	if level.mode != Utils.LevelMode.Survival:
		var heading : Label = Label.new()
		heading.text = SO_FAR_TEXT
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_color_override(&"font_color", SUBTITLE_COLOR)
		lines.append(heading)
		lines.append(LevelCompletedMenu.build_checklist(TalentRules.point_conditions_for_level(level, false)))
	var gap : Control = Control.new()
	gap.custom_minimum_size.y = GAP
	lines.append(gap)
	for line in lines:
		title_label.get_parent().add_child(line)
		title_label.get_parent().move_child(line, title_label.get_index() + 1 + lines.find(line))


func _on_options_pressed() -> void:
	UISignals.options.emit()


func _on_quit_pressed() -> void:
	#save?
	UISignals.resign_level.emit()


func _on_continue_pressed() -> void:
	UISignals.continue_from_pause_menu.emit()
