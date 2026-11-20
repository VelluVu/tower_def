extends RefCounted

## Polish round 2 (2026-11-20): the wave banner, leak feedback, the placing range ring and the placement flash.


func _free_cell(kit : TestKit) -> Vector2i:
	return kit.find_cell(func(c : Vector2i) -> bool: return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))


func test_wave_banner_texts(kit : TestKit) -> void:
	await kit.load_level(8)
	var banner : WaveBanner = WaveBanner.new()
	kit.root.add_child(banner)
	banner.level = kit.level
	var runner : WaveRunner = kit.level.wave_runner
	banner._on_wave_started(1)
	kit.check(banner.title.text == WaveBanner.WAVE_TEXT % [1, runner.wave_count], "wave 1 reads Wave 1/N (%s)" % banner.title.text)
	banner._on_wave_started(runner.wave_count)
	kit.check(banner.title.text == WaveBanner.FINAL_WAVE_TEXT, "the last wave reads Final wave")
	kit.check(banner.warning.text == WaveBanner.BOSS_TEXT % "Broodmother", "the Broodmother's wave warns of her (%s)" % banner.warning.text)
	kit.check(banner.modulate.a == 1.0, "shown at full")
	banner.queue_free()


func test_flyer_warning_once(kit : TestKit) -> void:
	await kit.load_level(6)
	var banner : WaveBanner = WaveBanner.new()
	kit.root.add_child(banner)
	banner.level = kit.level
	var runner : WaveRunner = kit.level.wave_runner
	var warned : int = 0
	for wave in runner.waves.size():
		banner._on_wave_started(wave + 1)
		if banner.warning.text == WaveBanner.FLYERS_TEXT:
			warned += 1
	kit.check(warned == 1, "Bat Roost warns of flyers once (%d)" % warned)
	banner.queue_free()


func test_leak_costs_life_with_feedback(kit : TestKit) -> void:
	await kit.load_level(1)
	var lost : Array[int] = []
	var on_lost : Callable = func(_position : Vector2, amount : int) -> void: lost.append(amount)
	GameSignals.life_lost.connect(on_lost)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	GameSignals.enemy_reached_end_point.emit(enemy)
	GameSignals.life_lost.disconnect(on_lost)
	kit.check(lost.size() == 1 and lost[0] >= 1, "a leak reports the life it cost (%s)" % str(lost))


func test_life_counter_flashes_on_drop(kit : TestKit) -> void:
	var display : ResourceDisplay = load("res://scenes/ui/resource_display/resource_display.tscn").instantiate()
	kit.root.add_child(display)
	await kit.frames(1)
	var life : ResourceDisplayElement = display.resource_display_elements[ResourceDisplay.LIFE_INDEX]
	display._resource_change(10, ResourceDisplay.LIFE_INDEX)
	kit.check(life.flash_tween == null, "setting life up does not flash")
	display._resource_change(9, ResourceDisplay.LIFE_INDEX)
	kit.check(life.flash_tween != null and life.flash_tween.is_running(), "a drop flashes")
	display.queue_free()


func test_range_ring_while_placing(kit : TestKit) -> void:
	await kit.load_level(1)
	var tower : Building = load(TestKit.BUILDING_PATH % "puffe_bolter").instantiate()
	kit._get_buildings_container().add_child(tower)
	await kit.frames(1)
	tower.is_placing = true
	var ring : RangeArea = tower.get_node("RangeArea")
	kit.check(ring._is_shown(), "the ring shows while placing")
	tower.is_valid_placement = false
	kit.check(not ring._is_valid(), "red on a blocked spot")
	tower.queue_free()


func test_placement_flash(kit : TestKit) -> void:
	await kit.load_level(1)
	var tower : Building = await kit.place("puffe_bolter", _free_cell(kit))
	var shader : ShaderMaterial = tower.animation_control.material as ShaderMaterial
	kit.check(shader.get_shader_parameter(&"hit_color") == BuildingPlacementDrawer.PLACED_FLASH_COLOR, "a new tower flashes mint")
	tower.animation_control.play_hit_animation()
	kit.check(shader.get_shader_parameter(&"hit_color") != BuildingPlacementDrawer.PLACED_FLASH_COLOR, "a hit flashes its own colour again")
