extends RefCounted

## The game camera: zoom in whole steps at the cursor, 1x-3x, and a grab-and-drag that follows the mouse.


func _make_camera(kit : TestKit, level_number : int) -> GameCamera:
	var camera : GameCamera = GameCamera.new()
	kit.root.add_child(camera)
	await kit.load_level(level_number)
	return camera


#the world point drawn at a viewport point
func _world_at(camera : GameCamera, screen_point : Vector2) -> Vector2:
	return camera.global_position + (screen_point - camera.get_viewport_rect().size * 0.5) / camera.zoom


func test_zoom_keeps_the_point_under_the_cursor(kit : TestKit) -> void:
	var camera : GameCamera = await _make_camera(kit, 13)
	kit.check(camera.current_mode == GameCamera.CameraMode.Free, "the level frames the camera")
	var size : Vector2 = camera.get_viewport_rect().size
	camera._zoom_at(size * 0.5, 2.0)
	#a point off centre, away from the limits, so nothing clamps
	var cursor : Vector2 = size * Vector2(0.3, 0.6)
	var before : Vector2 = _world_at(camera, cursor)
	camera._zoom_at(cursor, 3.0)
	kit.check(camera.zoom == Vector2(3, 3), "zoomed straight to 3x, no in-between")
	var after : Vector2 = _world_at(camera, cursor)
	kit.check_near(after.x, before.x, "same world x under the cursor")
	kit.check_near(after.y, before.y, "same world y under the cursor")
	camera._zoom_at(cursor, 2.0)
	after = _world_at(camera, cursor)
	kit.check_near(after.x, before.x, "and back out at 2x")
	camera.queue_free()


func test_zoom_out_stays_in_the_level(kit : TestKit) -> void:
	var camera : GameCamera = await _make_camera(kit, 13)
	var size : Vector2 = camera.get_viewport_rect().size
	camera._zoom_at(size * 0.5, 3.0)
	camera._zoom_at(Vector2.ZERO, camera._get_min_zoom())
	var half : Vector2 = size * 0.5 / camera.zoom
	kit.check(camera.global_position.x - half.x >= camera.limit_left - 0.001, "left edge inside the level")
	kit.check(camera.global_position.x + half.x <= camera.limit_right + 0.001, "right edge inside the level")
	camera.queue_free()


func test_zoom_limits(kit : TestKit) -> void:
	var camera : GameCamera = await _make_camera(kit, 13)
	kit.check(camera.zoom_max == Vector2(3, 3), "zoom in stops at 3x")
	kit.check(camera._get_min_zoom() >= 1.0 and camera._get_min_zoom() <= camera.zoom_max.x, "the widest zoom is a whole step under the cap")
	kit.check(camera.zoom.x == roundf(camera.zoom.x), "the start zoom is a whole step")
	camera.queue_free()


func test_key_scroll_speed_is_the_same_on_screen(kit : TestKit) -> void:
	var camera : GameCamera = await _make_camera(kit, 13)
	var size : Vector2 = camera.get_viewport_rect().size
	var screen_moves : Array[float] = []
	for zoom_level in [1.0, 3.0]:
		camera._zoom_at(size * 0.5, zoom_level)
		var start : Vector2 = camera.global_position
		camera.move_direction = Vector2.RIGHT
		camera._move_camera_smoothly(1.0 / 60.0)
		screen_moves.append((camera.global_position.x - start.x) * zoom_level)
	camera.move_direction = Vector2.ZERO
	kit.check(screen_moves[0] > 0.0, "the key scrolls")
	kit.check_near(screen_moves[1], screen_moves[0], "one frame scrolls the same screen distance at 1x and 3x")
	camera.queue_free()


func test_drag_follows_the_mouse(kit : TestKit) -> void:
	var camera : GameCamera = await _make_camera(kit, 13)
	var size : Vector2 = camera.get_viewport_rect().size
	camera._zoom_at(size * 0.5, 2.0)
	var start : Vector2 = camera.global_position
	#the grab as _set_is_panning records it, then a 20 px drag to the right
	camera.pan_initial_position = Vector2(100, 100)
	camera.pan_start_camera_position = start
	var dragged : Vector2 = Vector2(120, 100) - camera.pan_initial_position
	camera.global_position = camera._clamp_to_limits(camera.pan_start_camera_position - dragged / camera.zoom)
	kit.check_near(camera.global_position.x, start.x - 10.0, "20 viewport px at 2x moves the world 10 px")
	kit.check_near(camera.global_position.y, start.y, "no vertical drift")
	camera.queue_free()
