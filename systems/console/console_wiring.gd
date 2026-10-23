class_name ConsoleWiring
extends Node

## The file to edit when this system moves: the only one here that knows the project
## (command sets, developer mode, input actions, log signals, wording). DevConsole adds it
## as a child, so its connections go with it.

## Gitignored cheat sets, loaded by path if present. The console lives in Main for the
## whole session, so every set is added once; the level cheats check for a level themselves.
const CHEAT_SET_PATHS: Array[String] = [
	"res://scenes/console/dev_mode_commands.gd",
	"res://scenes/console/level_cheat_commands.gd",
]

const TITLE_TEXT: String = "Console"
const CLOSE_ICON: String = "x"
const PLACEHOLDER_TEXT: String = "Type a command... (help)"
const READY_MESSAGE: String = "Console ready. Type 'help' to see the commands."
const DEV_MODE_OFF_MESSAGE: String = "[color=orange]Developer commands are off.[/color]"

## Gameplay event lines; `log hide` / `log show` hides or shows them.
const EVENT_CATEGORY: StringName = &"event"
const LOG_USAGE_TEXT: String = "log show|hide"
const EVENTS_SHOWN_MESSAGE: String = "Event log shown."
const EVENTS_HIDDEN_MESSAGE: String = "Event log hidden. Back with: log show"
const LOG_HIDE_ARG: String = "hide"

const LEVEL_LOADED_FORMAT: String = "[color=lightblue]Level loaded: %s[/color]"
const WAVE_STARTED_FORMAT: String = "Wave %d/%d started"
const WAVE_CLEARED_FORMAT: String = "[color=lightgreen]Wave %d cleared[/color]"
const LEVEL_COMPLETED_TEXT: String = "[color=gold]Level completed![/color]"
const LOSE_TEXT: String = "[color=red]Level lost.[/color]"
const LEAK_FORMAT: String = "[color=orange]%s reached the end: -%d life[/color]"
const BUILDING_DESTROYED_FORMAT: String = "[color=orange]%s destroyed[/color]"
const UPGRADE_LEVEL_FORMAT: String = "[color=gold]Upgrade level %d[/color]"
const DEV_MODE_ON_TEXT: String = "[color=lightgreen]Developer mode on.[/color]"
const DEV_MODE_OFF_TEXT: String = "[color=orange]Developer mode off.[/color]"

var _console: DevConsole
## Logs a wave start once, wave_state_changed is emitted on every state refresh.
var _last_wave_number: int = 0


func _ready() -> void:
	_console = get_parent() as DevConsole
	_console.title_label.text = TITLE_TEXT
	_console.input_line_edit.placeholder_text = PLACEHOLDER_TEXT
	_console.open_action = InputManager.ACTION_OPEN_CONSOLE
	_console.cancel_action = InputManager.ACTION_CANCEL
	# Out of the way until C; the pixel font has no arrow glyphs, so the toggle just closes it.
	_console.hide_when_collapsed = true
	_console.collapse_icon = CLOSE_ICON
	_console.expand_icon = CLOSE_ICON
	# The builder and unit selection ignore clicks while the cursor is over a GUI panel.
	_console.mouse_entered.connect(func() -> void: UISignals.mouse_on_gui.emit(true))
	_console.mouse_exited.connect(func() -> void: UISignals.mouse_on_gui.emit(false))

	var registry: ConsoleCommandRegistry = _console.registry
	registry.developer_mode_check = func() -> bool: return GameSignals.developer_mode
	registry.dev_mode_off_message = DEV_MODE_OFF_MESSAGE
	registry.register("log", _cmd_log, LOG_USAGE_TEXT)
	for path: String in CHEAT_SET_PATHS:
		registry.add_optional_command_set(path)

	_connect_log_sources()
	_console.log_line(READY_MESSAGE)


func _connect_log_sources() -> void:
	GameSignals.level_loaded.connect(func(level: Level) -> void:
		_last_wave_number = 0
		_log_event(LEVEL_LOADED_FORMAT % level.name))
	GameSignals.wave_state_changed.connect(_on_wave_state_changed)
	GameSignals.wave_cleared.connect(func(wave_number: int) -> void:
		_log_event(WAVE_CLEARED_FORMAT % wave_number))
	GameSignals.level_completed.connect(func(_level: Level) -> void: _log_event(LEVEL_COMPLETED_TEXT))
	GameSignals.lose_game.connect(func() -> void: _log_event(LOSE_TEXT))
	GameSignals.enemy_reached_end_point.connect(func(enemy: Enemy) -> void:
		_log_event(LEAK_FORMAT % [_unit_name(enemy), roundi(enemy.stats.get_stat_value(Utils.StatType.Damage))]))
	GameSignals.building_destroyed.connect(func(building: Building) -> void:
		_log_event(BUILDING_DESTROYED_FORMAT % _unit_name(building)))
	GameSignals.upgrade_level_gained.connect(func(new_level: int, _cards: Array[UpgradeCard]) -> void:
		_log_event(UPGRADE_LEVEL_FORMAT % new_level))
	GameSignals.developer_mode_changed.connect(func(is_enabled: bool) -> void:
		_console.log_line(DEV_MODE_ON_TEXT if is_enabled else DEV_MODE_OFF_TEXT))


func _on_wave_state_changed(wave_number: int, wave_count: int, _can_start_next: bool, _early_start_bonus: float) -> void:
	if wave_number <= _last_wave_number:
		return
	_last_wave_number = wave_number
	_log_event(WAVE_STARTED_FORMAT % [wave_number, wave_count])


## Spawned copies get generated node names (@Weakling@12), the scene file name reads better.
func _unit_name(unit: Node) -> String:
	return unit.scene_file_path.get_file().get_basename() if not unit.scene_file_path.is_empty() else String(unit.name)


func _log_event(bbcode_line: String) -> void:
	_console.log_line(bbcode_line, EVENT_CATEGORY)


## `log` alone flips the event lines; `log show` / `log hide` set them.
func _cmd_log(args: PackedStringArray) -> void:
	var hide_events: bool = not _console.is_category_hidden(EVENT_CATEGORY)
	if not args.is_empty():
		hide_events = args[0].to_lower() == LOG_HIDE_ARG
	_console.set_category_hidden(EVENT_CATEGORY, hide_events)
	_console.log_line(EVENTS_HIDDEN_MESSAGE if hide_events else EVENTS_SHOWN_MESSAGE)
