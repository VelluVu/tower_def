class_name InputWiring
extends InputBindings

## This project's shortcuts and wording: the file to edit after copying the input system.
## InputManager extends it, so game code reads InputManager.ACTION_*.
## The camera, building and click actions are still in project.godot's input map; move them
## here when the game gets a key binding menu.

const ACTION_CANCEL: StringName = &"menu_cancel"
const ACTION_OPEN_CONSOLE: StringName = &"open_console"


func _init() -> void:
	cancel_action = ACTION_CANCEL
	# DevConsole reads it in its own _input(), so it is a direct action.
	rebindable_actions = [
		ACTION_OPEN_CONSOLE,
	]
	direct_actions = [ACTION_OPEN_CONSOLE]
	default_keys = {
		ACTION_OPEN_CONSOLE: KEY_C,
	}
	action_labels = {
		ACTION_OPEN_CONSOLE: "Console",
	}
	save_path = "user://input_bindings.cfg"
