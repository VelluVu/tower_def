extends RefCounted

## Polish round 7 (2026-11-22): the world map's level panel (point gems, enemy roster, big Start),
## the card hover lift and tick.


func test_roster_lists_each_kind_once(kit : TestKit) -> void:
	var data : LevelData = kit.level_data(24)
	var roster : WavePreview = WavePreview.new()
	kit.root.add_child(roster)
	roster.show_roster(data.waves)
	var kinds : Dictionary[String, bool] = {}
	for wave in data.waves:
		for group in wave.spawn_groups:
			if group.enemy_scene != null:
				kinds[group.enemy_scene.resource_path] = true
	kit.check(roster.get_child_count() == kinds.size(), "one entry per kind (%d of %d)" % [roster.get_child_count(), kinds.size()])
	var labels : Array[Node] = roster.find_children("*", "Label", true, false)
	kit.check(labels.is_empty(), "a roster shows no counts")
	roster.queue_free()


func test_level_panel_shows_points_and_enemies(kit : TestKit) -> void:
	PlayerProgress.level_progress = maxi(PlayerProgress.level_progress, 7)
	PlayerProgress.record_level_talent_points(6, 3, Utils.LevelMode.Normal)
	var map : Node = (load("res://scenes/ui/game_world_map/game_world_map.tscn") as PackedScene).instantiate()
	kit.root.add_child(map)
	await kit.frames(2)
	var element : MapLevelElement = map.find_child("Level_006", true, false) as MapLevelElement
	kit.check(element.point_icons.size() == TalentRules.MAX_POINTS_PER_LEVEL, "five point gems")
	var earned : int = element.point_icons.filter(func(icon : TextureRect) -> bool: return icon.texture == MapLevelElement.POINT_EARNED).size()
	kit.check(earned == PlayerProgress.get_level_mode_talent_points(6, Utils.LevelMode.Normal), "Normal's points are gold (%d)" % earned)
	element._on_mode_tab_pressed(Utils.LevelMode.Hard)
	var hard_earned : int = element.point_icons.filter(func(icon : TextureRect) -> bool: return icon.texture == MapLevelElement.POINT_EARNED).size()
	kit.check(hard_earned == PlayerProgress.get_level_mode_talent_points(6, Utils.LevelMode.Hard), "switching to Hard shows its points (%d)" % hard_earned)
	kit.check(element.tooltip.find_children("*", "WavePreview", true, false).size() == 1, "an enemy roster in the panel")
	kit.check(element.start_button.theme_type_variation == MapLevelElement.START_BUTTON_VARIATION, "a big Start button")
	map.queue_free()


func test_card_hover_lifts_and_ticks(kit : TestKit) -> void:
	var menu : LevelUpMenu = (load("res://scenes/ui/level_up_menu/level_up_menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	var content : Control = Control.new()
	menu.add_child(content)
	var ticks : Array[bool] = []
	var on_tick : Callable = func() -> void: ticks.append(true)
	UISignals.upgrade_card_hovered.connect(on_tick)
	menu._on_card_hovered(content, true)
	kit.check(content.offset_top == -LevelUpMenu.HOVER_LIFT and ticks.size() == 1, "lifted with a tick")
	menu._on_card_hovered(content, false)
	kit.check(content.offset_top == 0.0 and ticks.size() == 1, "back down, no tick on the way out")
	UISignals.upgrade_card_hovered.disconnect(on_tick)
	menu.queue_free()
