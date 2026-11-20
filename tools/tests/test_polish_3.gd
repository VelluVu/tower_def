extends RefCounted

## Polish round 3 (2026-11-20): keyboard shortcuts, the kill gold "+N" and the playtest log after early starts.

func test_shortcut_actions_are_registered(kit : TestKit) -> void:
	for action : StringName in InputManager.ACTION_BUILD_SLOTS + [InputManager.ACTION_START_WAVE, InputManager.ACTION_SPEED_UP, InputManager.ACTION_UPGRADE_SELECTED, InputManager.ACTION_SELL_SELECTED]:
		kit.check(InputMap.has_action(action) and InputManager.get_keycode(action) != KEY_NONE, "%s has a key" % action)
	var used : Dictionary = {}
	for action : StringName in InputManager.rebindable_actions:
		used[InputManager.default_keys[action]] = true
	kit.check(used.size() == InputManager.rebindable_actions.size(), "no two default shortcuts share a key")


func test_upgrade_shortcut_skips_choices(kit : TestKit) -> void:
	var plain : GoldUpgradeOption = GoldUpgradeOption.upgrade("Up 1", null, 5.0)
	var poor : GoldUpgradeOption = GoldUpgradeOption.upgrade("Up 2", null, 50.0)
	var element : GoldUpgradeOption = GoldUpgradeOption.upgrade("Fire", null, 5.0)
	element.element_leaf_path = NodePath("EvolveTree/Fire")
	var wall_element : GoldUpgradeOption = GoldUpgradeOption.wall_element_option(Utils.Element.Frost, "Frost", null, 3.0)
	var tier : GoldUpgradeOption = GoldUpgradeOption.upgrade("T2", null, 9.0)
	tier.element_leaf_path = NodePath("EvolveTree/Fire")
	tier.tier = 1
	plain.is_affordable = true
	element.is_affordable = true
	wall_element.is_affordable = true
	tier.is_affordable = true

	var choices : Array[GoldUpgradeOption] = [element, wall_element]
	kit.check(UnitSelectionPanel.get_shortcut_upgrade_index(choices) == -1, "an element pick is never bought by the key")
	var options : Array[GoldUpgradeOption] = [poor, element, plain]
	kit.check(UnitSelectionPanel.get_shortcut_upgrade_index(options) == 2, "the first affordable plain upgrade")
	var tiers : Array[GoldUpgradeOption] = [tier]
	kit.check(UnitSelectionPanel.get_shortcut_upgrade_index(tiers) == 0, "a tier is bought by the key")
	tier.is_locked = true
	kit.check(UnitSelectionPanel.get_shortcut_upgrade_index(tiers) == -1, "a locked tier is not")


func test_build_slot_shortcut_toggles_placement(kit : TestKit) -> void:
	await kit.load_level(1)
	var builder : Builder = Builder.new()
	kit.root.add_child(builder)
	builder.level = kit.level
	builder.available_buildings = builder.buildings.slice(0, 2)
	kit.check(builder.available_buildings.size() == 2, "two tray slots for the test (%d)" % builder.available_buildings.size())
	builder.is_ready_to_build = true
	InputManager.shortcut_pressed.emit(InputManager.ACTION_BUILD_SLOTS[0])
	kit.check(builder.is_placing_building and builder.current_building_option_index == 0, "key 1 picks the first tray slot")
	InputManager.shortcut_pressed.emit(InputManager.ACTION_BUILD_SLOTS[0])
	kit.check(not builder.is_placing_building, "pressing it again puts it away")
	InputManager.shortcut_pressed.emit(InputManager.ACTION_BUILD_SLOTS[4])
	kit.check(not builder.is_placing_building, "a slot past the tray does nothing")
	builder.queue_free()


func test_kill_pays_gold_with_a_number(kit : TestKit) -> void:
	await kit.load_level(1)
	var earned : Array[float] = []
	var on_earned : Callable = func(_position : Vector2, amount : float) -> void: earned.append(amount)
	GameSignals.gold_earned.connect(on_earned)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var gold : float = kit.level.player_stats.gold
	enemy.die()
	await kit.frames(2)
	GameSignals.gold_earned.disconnect(on_earned)
	kit.check(earned.size() == 1 and earned[0] > 0.0, "a kill reports its gold (%s)" % str(earned))
	kit.check_near(kit.level.player_stats.gold - gold, earned[0] if not earned.is_empty() else 0.0, "the reported gold is what was paid")


func test_early_start_keeps_one_entry_per_wave(kit : TestKit) -> void:
	await kit.load_level(1)
	var log : PlaytestLog = null
	for child in kit.level.get_children():
		if child is PlaytestLog:
			log = child
	if log == null:
		log = PlaytestLog.new()
		log.level = kit.level
		kit.level.add_child(log)
	log.life_by_wave.clear()
	log.gold_by_wave.clear()
	#wave 1 starts, wave 2 starts early (wave 1 never clears), then the field clears
	log._on_wave_started(1)
	log._on_wave_started(2)
	log._on_wave_cleared(2)
	kit.check(log.life_by_wave.size() == 2 and log.gold_by_wave.size() == 2, "two waves, two entries (%d)" % log.life_by_wave.size())
	log._on_wave_started(3)
	log._on_wave_cleared(3)
	kit.check(log.life_by_wave.size() == 3, "a normal clear adds one (%d)" % log.life_by_wave.size())
