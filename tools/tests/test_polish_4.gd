extends RefCounted

## Polish round 4 (2026-11-22): rich tooltips (systems/tooltip) and upgrade buttons that say what they give.

const BOLTER_SCENE : String = "res://scenes/unit/building/buildings/puffe_bolter.tscn"
const BOLTER_DATA : String = "res://scenes/upgrades/building_upgrades/bolter_upgrade_data.tres"
const WALL_DATA : String = "res://scenes/upgrades/building_upgrades/wall_upgrade_data.tres"


func test_rich_tooltip_builds_title_and_body(kit : TestKit) -> void:
	kit.check(RichTooltip.build("") == null and RichTooltip.build("  \n") == null, "no tooltip for empty text")
	var label : RichTextLabel = RichTooltip.build("Sell  [X]\nRefunds 5g, +2 bonus gold") as RichTextLabel
	kit.check(label != null, "a label")
	if label == null:
		return
	kit.check(label.text.begins_with("[b]"), "the title is bold: %s" % label.text)
	kit.check(label.text.contains("[lb]X]") and not label.text.contains(" [X]"), "the key hint is escaped, never read as a tag")
	kit.check(label.text.contains("[color=#%s]" % TooltipWiring.HIGHLIGHTS[0][1].to_html(false)), "the key hint is coloured")
	kit.check(label.text.contains("5g[/color]") and label.text.contains("+2 bonus gold[/color]"), "gold amounts are coloured: %s" % label.text)
	kit.check(label.custom_minimum_size.x > 0.0 and label.custom_minimum_size.x < TooltipWiring.MAX_WIDTH, "short text keeps its own width (%.0f)" % label.custom_minimum_size.x)
	label.free()

	var long_text : String = "Title\n" + "word ".repeat(60)
	var wide : RichTextLabel = RichTooltip.build(long_text) as RichTextLabel
	kit.check(is_equal_approx(wide.custom_minimum_size.x, TooltipWiring.MAX_WIDTH), "long text wraps at the max width")
	kit.check(wide.autowrap_mode != TextServer.AUTOWRAP_OFF and wide.fit_content, "it wraps and grows to fit")
	wide.free()


func test_scene_buttons_use_rich_tooltips(kit : TestKit) -> void:
	var scenes : Dictionary[String, Array] = {
		"res://scenes/ui/wave_panel/wave_panel.tscn": [^"MarginContainer/Panel/MarginContainer/VBoxContainer/StartWaveButton"],
		"res://scenes/ui/speed_control/speed_control_panel.tscn": [^"MarginContainer/Panel/MarginContainer/HBoxContainer/Slower", ^"MarginContainer/Panel/MarginContainer/HBoxContainer/Faster"],
	}
	for path : String in scenes:
		var scene : Node = (load(path) as PackedScene).instantiate()
		for node_path : NodePath in scenes[path]:
			kit.check(scene.get_node_or_null(node_path) is RichTooltipButton, "%s %s" % [path.get_file(), node_path])
		scene.free()
	var bottom : Node = (load("res://scenes/ui/bottom_panel/bottom_panel.tscn") as PackedScene).instantiate()
	var tray_buttons : Array[Node] = bottom.find_children("SelectBuildingButton", "Button", true, false)
	kit.check(not tray_buttons.is_empty() and tray_buttons.all(func(button : Node) -> bool: return button is RichTooltipButton), "every tray slot (%d)" % tray_buttons.size())
	kit.check(bottom.find_child("SellButton", true, false) is RichTooltipButton, "the Sell button")
	bottom.free()


func test_upgrade_tooltips_say_what_they_give(kit : TestKit) -> void:
	var data : BuildingUpgradeData = load(BOLTER_DATA)
	var plain : String = UpgradeTooltipText.for_upgrade(data, false)
	kit.check(plain.contains("Damage +20%") and plain.contains("Attack Speed +10%"), "plain upgrade: %s" % plain)
	kit.check(not plain.contains("Potency") and plain.contains(UpgradeTooltipText.THIS_TOWER_TEXT), "no potency before the element, this tower only")
	kit.check(UpgradeTooltipText.for_upgrade(data, true).contains("Effect Potency +30%"), "Up 3 after the element adds potency")
	kit.check(UpgradeTooltipText.for_upgrade(load(WALL_DATA), false).contains(UpgradeTooltipText.EVERY_WALL_TEXT), "a wall upgrade is for every wall")

	var bolter : Building = (load(BOLTER_SCENE) as PackedScene).instantiate()
	var fire : ElementEvolveLeaf = bolter.find_child("FireElementEvolveLeaf", true, false)
	var physical : ElementEvolveLeaf = bolter.find_child("PhysicalElementEvolveLeaf", true, false)
	var fire_text : String = UpgradeTooltipText.for_element(fire)
	kit.check(fire_text.contains("burning") and fire_text.contains("Damage ×11%"), "Fire: %s" % fire_text)
	var physical_text : String = UpgradeTooltipText.for_element(physical)
	kit.check(physical_text.contains("Critical Chance +10%"), "a flat chance reads as percent: %s" % physical_text)

	var option : GoldUpgradeOption = GoldUpgradeOption.evolve_tier(fire, bolter, 0, 10.0)
	kit.check(option.title == "T2" or option.is_locked, "a tier's title is short: %s" % option.title)
	kit.check(option.description.begins_with(fire.tiers[0].info), "its body is the tier's info: %s" % option.description)
	var tooltip : String = UnitSelectionPanel.get_upgrade_tooltip(option, true)
	var key_suffix : String = UnitSelectionPanel.UPGRADE_KEY_SUFFIX % InputManager.get_binding_text(InputManager.ACTION_UPGRADE_SELECTED)
	kit.check(tooltip.split("\n")[0].ends_with(key_suffix), "the shortcut's key is in the title: %s" % tooltip)
	var element_option : GoldUpgradeOption = GoldUpgradeOption.evolve(fire, bolter, 6.0)
	kit.check(UnitSelectionPanel.get_upgrade_tooltip(element_option, false).ends_with(UnitSelectionPanel.ELEMENT_CHOICE_TOOLTIP), "an element pick says it stays")
	bolter.free()

	var wall_option : GoldUpgradeOption = GoldUpgradeOption.wall_element_option(Utils.Element.Frost, "Frost wall", null, 2.0)
	wall_option.description = UpgradeTooltipText.for_wall_element(Utils.Element.Frost)
	kit.check(not UnitSelectionPanel.get_upgrade_tooltip(wall_option, false).contains(UnitSelectionPanel.ELEMENT_CHOICE_TOOLTIP), "a wall element does not say 'this tower'")
	kit.check(UpgradeTooltipText.for_wall_tier(Utils.Element.Fire, "Fire wall", 3, true).contains("Explodes") , "wall T3 names its effect")


func test_wave_preview_lists_the_coming_wave(kit : TestKit) -> void:
	var soldier : PackedScene = load("res://scenes/unit/enemy/enemies/soldier.tscn")
	var batling : PackedScene = load("res://scenes/unit/enemy/enemies/batling.tscn")
	var boss : PackedScene = load("res://scenes/unit/enemy/enemies/dragonslayer.tscn")
	kit.check(WavePreview.enemy_kind(batling).flying and not WavePreview.enemy_kind(soldier).flying, "a batling flies, a soldier walks")
	kit.check(WavePreview.enemy_kind(boss).boss, "the Dragonslayer is a boss")

	var wave : WaveData = WaveData.new()
	for setup : Array in [[soldier, 6, 2], [batling, 4, 0], [soldier, 3, 0], [boss, 1, 0]]:
		var group : SpawnGroupData = SpawnGroupData.new()
		group.enemy_scene = setup[0]
		group.count = setup[1]
		group.elites = setup[2]
		wave.spawn_groups.append(group)
	var entries : Array[Dictionary] = WavePreview.summarize(wave)
	kit.check(entries.size() == 4, "soldiers, elite soldiers, batlings, the boss (%d)" % entries.size())
	kit.check(entries[0].count == 7 and not entries[0].elite, "two soldier groups merge, elites apart: %d" % entries[0].count)
	kit.check(entries[1].count == 2 and entries[1].elite, "the elites: %d" % entries[1].count)
	var text : String = WavePreview.describe(wave)
	kit.check(text.contains("4 Batling (flying)") and text.contains("2 elite Soldier") and text.contains("Boss: Dragonslayer"), "tooltip: %s" % text)

	var preview : WavePreview = WavePreview.new()
	kit.root.add_child(preview)
	preview.show_wave(wave)
	kit.check(preview.visible and preview.get_child_count() == 4, "one entry per kind")
	preview.show_wave(null)
	kit.check(not preview.visible, "no next wave hides the row")
	preview.queue_free()


func test_wave_panel_previews_the_level(kit : TestKit) -> void:
	await kit.load_level(6)
	var runner : WaveRunner = kit.level.wave_runner
	kit.check(runner.next_wave != null, "level 6 has a first wave")
	var text : String = WavePreview.describe(runner.next_wave)
	kit.check(text.begins_with(WavePreview.NEXT_TITLE) and text.count("\n") >= 1, "the first wave reads: %s" % text)


func test_stat_icons_and_badges_load(kit : TestKit) -> void:
	for stat : Utils.StatType in HorizontalStatField.STAT_ICONS:
		var icon : Texture2D = HorizontalStatField.STAT_ICONS[stat]
		kit.check(icon != null and icon.get_size() == Vector2(7, 7), "stat icon %s is 7x7" % Utils.StatType.keys()[stat])
	for badge : Texture2D in [WavePreview.FLYER_BADGE, WavePreview.ELITE_BADGE, WavePreview.BOSS_BADGE]:
		kit.check(badge.get_size() == Vector2(WavePreview.BADGE_SIZE, WavePreview.BADGE_SIZE), "badge %s" % badge.resource_path.get_file())


func test_win_screen_lists_the_point_conditions(kit : TestKit) -> void:
	for case : Array in [[10, 10, 5, 5], [5, 10, 2, 5], [4, 10, 0, 5], [10, 10, 0, 0], [7, 10, 3, 5]]:
		var conditions : Array[Dictionary] = TalentRules.point_conditions(case[0], case[1], case[2], case[3])
		var met : int = conditions.filter(func(condition : Dictionary) -> bool: return condition.met).size()
		kit.check(conditions.size() == TalentRules.MAX_POINTS_PER_LEVEL and met == TalentRules.points_for_result(case[0], case[1], case[2], case[3]), "the checklist adds up to the points for %s" % [case])
	var half : Array[Dictionary] = TalentRules.point_conditions(5, 10, 2, 5)
	kit.check(half[1].text.contains("5/10") and half[3].text.contains("2/5"), "it shows the numbers: %s, %s" % [half[1].text, half[3].text])

	var menu : LevelCompletedMenu = (load("res://scenes/ui/level_completed_menu/level_completed_menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	menu.show_point_conditions(half)
	menu.show_point_conditions(half)
	var checklists : Array[Node] = menu.find_children(String(LevelCompletedMenu.CHECKLIST_NAME), "", true, false)
	kit.check(checklists.size() == 1 and checklists[0].get_children().filter(func(row : Node) -> bool: return row is HBoxContainer).size() == 5, "one checklist of five rows, even when shown twice")
	menu.free()


func test_lose_screen_names_the_leaks(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	kit.level.player_stats._on_enemy_reach_base(enemy)
	var leak : Dictionary = kit.level.player_stats.leaks.get(enemy.scene_file_path, {})
	kit.check(leak.get("count", 0) == 1 and leak.get("lives", 0) >= 1, "a leak is recorded per enemy kind: %s" % [leak])

	var soldier : String = "res://scenes/unit/enemy/enemies/soldier.tscn"
	var batling : String = "res://scenes/unit/enemy/enemies/batling.tscn"
	var boss : String = "res://scenes/unit/enemy/enemies/dragonslayer.tscn"
	var walkers : Dictionary[String, Dictionary] = {soldier: {"count": 6, "lives": 6}, batling: {"count": 1, "lives": 1}}
	var flyers : Dictionary[String, Dictionary] = {soldier: {"count": 2, "lives": 2}, batling: {"count": 4, "lives": 4}}
	var with_boss : Dictionary[String, Dictionary] = {batling: {"count": 8, "lives": 8}, boss: {"count": 1, "lives": 5}}
	kit.check(LoseGameMenu.get_tip(LoseGameMenu.get_leak_rows(walkers)) == LoseGameMenu.MAZE_TIP, "walkers: the maze tip")
	kit.check(LoseGameMenu.get_tip(LoseGameMenu.get_leak_rows(flyers)) == LoseGameMenu.FLYER_TIP, "mostly flyers: the flyer tip")
	kit.check(LoseGameMenu.get_tip(LoseGameMenu.get_leak_rows(with_boss)) == LoseGameMenu.BOSS_TIP, "a boss beats the flyers")
	var rows : Array[Dictionary] = LoseGameMenu.get_leak_rows(with_boss)
	kit.check(rows[0].name == "Batling" and rows[0].lives == 8, "most lives first")

	var menu : LoseGameMenu = (load("res://scenes/ui/lose_game_menu/lose_game_menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	menu.show_defeat(4, 6, walkers)
	var summary : Node = menu.find_child(String(LoseGameMenu.DEFEAT_BOX_NAME), true, false)
	kit.check(summary != null and (summary.get_child(0) as Label).text == "Wave 4/6 broke through", "names the wave")
	kit.check(summary.get_children().filter(func(row : Node) -> bool: return row is HBoxContainer).size() == 2, "one row per kind")
	menu.free()


#(review, 2026-11-23): the pause menu marked the clear as earned while the level was still being played
func test_clear_condition_waits_for_the_win(kit : TestKit) -> void:
	var playing : Array[Dictionary] = TalentRules.point_conditions(10, 10, 0, 4, false)
	kit.check(not playing[0]["met"], "mid-level: Castle saved not earned yet")
	var won : Array[Dictionary] = TalentRules.point_conditions(10, 10, 0, 4)
	kit.check(won[0]["met"], "the win screen still counts it")
