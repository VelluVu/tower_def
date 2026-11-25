class_name InputWiring
extends InputBindings

## This project's shortcuts and wording: the file to edit after copying the input system.
## InputManager extends it, so game code reads InputManager.ACTION_*.
## The camera, building and click actions are still in project.godot's input map; move them
## here when the game gets a key binding menu.

const ACTION_CANCEL: StringName = &"menu_cancel"
const ACTION_OPEN_CONSOLE: StringName = &"open_console"
## The build tray's slots, left to right (the tray hides locked buildings, so slot N is the Nth shown).
const ACTION_BUILD_SLOTS: Array[StringName] = [&"build_slot_1", &"build_slot_2", &"build_slot_3", &"build_slot_4", &"build_slot_5", &"build_slot_6", &"build_slot_7", &"build_slot_8", &"build_slot_9", &"build_slot_10", &"build_slot_11", &"build_slot_12"]
const ACTION_START_WAVE: StringName = &"start_wave"
const ACTION_SPEED_DOWN: StringName = &"speed_down"
const ACTION_SPEED_UP: StringName = &"speed_up"
const ACTION_UPGRADE_SELECTED: StringName = &"upgrade_selected"
const ACTION_SELL_SELECTED: StringName = &"sell_selected"
## The camera goes back to the level's start view (spawners and castles in sight).
const ACTION_FRAME_LEVEL: StringName = &"frame_level"


func _init() -> void:
	cancel_action = ACTION_CANCEL
	# DevConsole reads it in its own _input(), so it is a direct action.
	rebindable_actions = [
		ACTION_BUILD_SLOTS[0], ACTION_BUILD_SLOTS[1], ACTION_BUILD_SLOTS[2], ACTION_BUILD_SLOTS[3], ACTION_BUILD_SLOTS[4], ACTION_BUILD_SLOTS[5], ACTION_BUILD_SLOTS[6], ACTION_BUILD_SLOTS[7], ACTION_BUILD_SLOTS[8], ACTION_BUILD_SLOTS[9], ACTION_BUILD_SLOTS[10], ACTION_BUILD_SLOTS[11],
		ACTION_START_WAVE,
		ACTION_SPEED_DOWN,
		ACTION_SPEED_UP,
		ACTION_UPGRADE_SELECTED,
		ACTION_SELL_SELECTED,
		ACTION_FRAME_LEVEL,
		ACTION_OPEN_CONSOLE,
	]
	direct_actions = [ACTION_OPEN_CONSOLE]
	default_keys = {
		ACTION_BUILD_SLOTS[0]: KEY_1,
		ACTION_BUILD_SLOTS[1]: KEY_2,
		ACTION_BUILD_SLOTS[2]: KEY_3,
		ACTION_BUILD_SLOTS[3]: KEY_4,
		ACTION_BUILD_SLOTS[4]: KEY_5,
		ACTION_BUILD_SLOTS[5]: KEY_6,
		ACTION_BUILD_SLOTS[6]: KEY_7,
		ACTION_BUILD_SLOTS[7]: KEY_8,
		ACTION_BUILD_SLOTS[8]: KEY_9,
		ACTION_BUILD_SLOTS[9]: KEY_0,
		ACTION_BUILD_SLOTS[10]: KEY_MINUS,
		ACTION_BUILD_SLOTS[11]: KEY_EQUAL,
		ACTION_START_WAVE: KEY_SPACE,
		ACTION_SPEED_DOWN: KEY_Q,
		ACTION_SPEED_UP: KEY_E,
		ACTION_UPGRADE_SELECTED: KEY_U,
		ACTION_SELL_SELECTED: KEY_X,
		ACTION_FRAME_LEVEL: KEY_F,
		ACTION_OPEN_CONSOLE: KEY_C,
	}
	action_labels = {
		ACTION_BUILD_SLOTS[0]: "Build slot 1",
		ACTION_BUILD_SLOTS[1]: "Build slot 2",
		ACTION_BUILD_SLOTS[2]: "Build slot 3",
		ACTION_BUILD_SLOTS[3]: "Build slot 4",
		ACTION_BUILD_SLOTS[4]: "Build slot 5",
		ACTION_BUILD_SLOTS[5]: "Build slot 6",
		ACTION_BUILD_SLOTS[6]: "Build slot 7",
		ACTION_BUILD_SLOTS[7]: "Build slot 8",
		ACTION_BUILD_SLOTS[8]: "Build slot 9",
		ACTION_BUILD_SLOTS[9]: "Build slot 10",
		ACTION_BUILD_SLOTS[10]: "Build slot 11",
		ACTION_BUILD_SLOTS[11]: "Build slot 12",
		ACTION_START_WAVE: "Start wave",
		ACTION_SPEED_DOWN: "Slower",
		ACTION_SPEED_UP: "Faster",
		ACTION_UPGRADE_SELECTED: "Upgrade selected",
		ACTION_SELL_SELECTED: "Sell selected",
		ACTION_FRAME_LEVEL: "Frame the level",
		ACTION_OPEN_CONSOLE: "Console",
	}
	save_path = "user://input_bindings.cfg"
