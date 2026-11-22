extends RefCounted

## Polish round 11 (2026-11-22): a boss's fall, "Castle saved!", castle rubble and the low-lives pulse.


func test_boss_fall_banner_and_ring(kit : TestKit) -> void:
	await kit.load_level(8)
	var banner : WaveBanner = WaveBanner.new()
	kit.root.add_child(banner)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	var puffs : DustPuffs = kit.level.get_node(Level.DUST_PUFFS_NAME) as DustPuffs
	var before : int = puffs.get_child_count()
	GameSignals.enemy_destroyed.emit(boss)
	kit.check(banner.title.text == WaveBanner.BOSS_DEFEATED_FORMAT % "Broodmother", "the banner names the boss: %s" % banner.title.text)
	kit.check(puffs.get_child_count() - before == DustPuffs.BOSS_RING_PUFFS, "a ring of puffs where it fell (%d)" % (puffs.get_child_count() - before))
	GameSignals.level_completed.emit(kit.level)
	kit.check(banner.warning.text == WaveBanner.CASTLE_SAVED_TEXT, "the win adds Castle saved under the boss")
	GameSignals.wave_started.emit(1)
	kit.check(not banner.title.has_theme_color_override(&"font_color"), "a later wave banner drops the gold")
	banner.queue_free()


func test_castle_saved_without_a_boss(kit : TestKit) -> void:
	var banner : WaveBanner = WaveBanner.new()
	kit.root.add_child(banner)
	GameSignals.level_completed.emit(null)
	kit.check(banner.title.text == WaveBanner.CASTLE_SAVED_TEXT, "Castle saved! as the title")
	banner.queue_free()


func test_leak_puffs_at_the_castle(kit : TestKit) -> void:
	await kit.load_level(6)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var puffs : DustPuffs = kit.level.get_node(Level.DUST_PUFFS_NAME) as DustPuffs
	puffs._recent.clear()
	var before : int = puffs.get_child_count()
	GameSignals.enemy_reached_end_point.emit(enemy)
	kit.check(puffs.get_child_count() == before + 1, "rubble where it got in")


func test_low_lives_pulse(kit : TestKit) -> void:
	var display : Node = (load("res://scenes/ui/resource_display/resource_display.tscn") as PackedScene).instantiate()
	kit.root.add_child(display)
	var life : ResourceDisplayElement = (display as ResourceDisplay).resource_display_elements[ResourceDisplay.LIFE_INDEX]
	GameSignals.resource_change.emit(10, ResourceDisplay.LIFE_INDEX)
	kit.check(life.alarm_tween == null, "no pulse at 10 lives")
	GameSignals.resource_change.emit(3, ResourceDisplay.LIFE_INDEX)
	kit.check(life.alarm_tween != null, "a pulse at %d lives" % ResourceDisplay.LOW_LIFE)
	GameSignals.resource_change.emit(5, ResourceDisplay.LIFE_INDEX)
	kit.check(life.alarm_tween == null, "it stops when lives come back")
	display.queue_free()
