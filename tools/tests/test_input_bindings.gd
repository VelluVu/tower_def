extends RefCounted

## Saved key bindings: an action added after the file was saved never takes a key the player gave to another one.

const TEST_PATH : String = "user://test_input_bindings.cfg"


func test_new_action_default_yields_to_a_saved_key(kit : TestKit) -> void:
	var real_path : String = InputManager.save_path
	InputManager.save_path = TEST_PATH
	var config : ConfigFile = ConfigFile.new()
	#an old save: Upgrade moved to the new action's default key, and no entry for the new action
	for action : StringName in InputManager.rebindable_actions:
		if action != InputManager.ACTION_FRAME_LEVEL:
			config.set_value(InputManager.SECTION_KEYS, String(action), InputManager.default_keys[action])
	config.set_value(InputManager.SECTION_KEYS, String(InputManager.ACTION_UPGRADE_SELECTED), InputManager.default_keys[InputManager.ACTION_FRAME_LEVEL])
	config.save(TEST_PATH)
	InputManager.load_bindings()
	kit.check(InputManager.get_keycode(InputManager.ACTION_UPGRADE_SELECTED) == InputManager.default_keys[InputManager.ACTION_FRAME_LEVEL], "the player's key stays on Upgrade")
	kit.check(InputManager.get_keycode(InputManager.ACTION_FRAME_LEVEL) == KEY_NONE, "the new action starts unbound")
	#back to the defaults for the other tests
	for action : StringName in InputManager.rebindable_actions:
		InputManager._apply_key(action, InputManager.default_keys[action])
	InputManager.save_path = real_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
