extends RefCounted

## The game's cursor (2026-11-24): the strongest request wins, the UI and pauses show a pointer, grabbing beats all,
## and the frames scale to the window's whole pixel scale.


func test_strongest_request_wins(kit : TestKit) -> void:
	var cursor : GameCursor = GameCursor.new()
	kit.root.add_child(cursor)
	await kit.frames(1)
	kit.check(cursor.current_mode() == GameCursor.Mode.POINTER, "nothing asked: a pointer")
	UISignals.cursor_mode_requested.emit(&"test_build", GameCursor.Mode.BUILD)
	UISignals.cursor_mode_requested.emit(&"test_hover", GameCursor.Mode.TARGET)
	kit.check(cursor.current_mode() == GameCursor.Mode.TARGET, "the target ring beats the build cursor")
	UISignals.cursor_mode_requested.emit(&"test_hover", GameCursor.Mode.POINTER)
	kit.check(cursor.current_mode() == GameCursor.Mode.BUILD, "letting go shows the next one")
	UISignals.mouse_on_gui.emit(true)
	kit.check(cursor.current_mode() == GameCursor.Mode.POINTER, "over the UI: a pointer")
	UISignals.cursor_mode_requested.emit(&"test_pan", GameCursor.Mode.GRAB)
	kit.check(cursor.current_mode() == GameCursor.Mode.GRAB, "grabbing shows even over the UI")
	UISignals.mouse_on_gui.emit(false)
	cursor._clear()
	kit.check(cursor.requests.is_empty() and cursor.current_mode() == GameCursor.Mode.POINTER, "a new scene clears every request")
	kit.check(GameCursor.scale_for(Vector2i(1280, 720)) == 2 and GameCursor.scale_for(Vector2i(1920, 1080)) == 3, "2x and 3x windows")
	kit.check(GameCursor.scale_for(Vector2i(600, 300)) == 1, "never below 1x")
	var first : Array = cursor.frames[GameCursor.Mode.BUILD]
	kit.check(first.size() == GameCursor.FRAME_SECONDS[GameCursor.Mode.BUILD].size(), "every build frame is made")
	kit.check((cursor.frames[GameCursor.POINTING_ROW] as Array).size() == 2 and (cursor.frames[GameCursor.PRESSED_ROW] as Array).size() == 1, "the pointing claw and the pressed arrow are made")
	var button : Button = Button.new()
	kit.root.add_child(button)
	kit.check(button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "a new button shows the pointing claw")
	button.queue_free()
	cursor.queue_free()
	await kit.frames(1)


func test_camera_pan_asks_for_the_claw(kit : TestKit) -> void:
	await kit.load_level(1)
	var seen : Dictionary[StringName, int] = {}
	var record : Callable = func(source : StringName, mode : int) -> void: seen[source] = mode
	UISignals.cursor_mode_requested.connect(record)
	var camera : GameCamera = GameCamera.new()
	kit.root.add_child(camera)
	await kit.frames(1)
	if camera != null:
		camera.is_panning = true
		kit.check(seen.get(GameCamera.CURSOR_SOURCE, -1) == GameCursor.Mode.GRAB, "panning the camera asks for the claw")
		camera.is_panning = false
		kit.check(seen.get(GameCamera.CURSOR_SOURCE, -1) == GameCursor.Mode.POINTER, "and lets go after")
	UISignals.cursor_mode_requested.disconnect(record)
	camera.queue_free()
	await kit.frames(1)
