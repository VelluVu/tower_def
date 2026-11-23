extends RefCounted

## Polish round 12 (2026-11-22): the pause menu's level info and live point checklist, resistance icons.


func test_resist_parts_strongest_first(kit : TestKit) -> void:
	var resistances : EnemyResistances = EnemyResistances.new()
	resistances.fire = 0.2
	resistances.poison = 0.4
	resistances.projectile = 0.3
	var parts : Array[Array] = resistances.get_parts()
	kit.check(parts.size() == 3 and parts[0][0] == "Poison" and parts[1][0] == "Bolter" and parts[2][0] == "Fire", "strongest first: %s" % [parts])
	kit.check(parts[0][2] == Utils.Element.Poison and parts[1][2] == Utils.Element.None, "elements carry their element, tower kinds None")
	kit.check(resistances.get_summary() == "Poison 40%, Bolter 30%, Fire 20%", "the summary still reads: %s" % resistances.get_summary())


func test_enemy_card_shows_resist_icons(kit : TestKit) -> void:
	var bottom : Node = (load("res://scenes/ui/bottom_panel/bottom_panel.tscn") as PackedScene).instantiate()
	kit.root.add_child(bottom)
	var panel : UnitSelectionPanel = bottom.find_children("*", "UnitSelectionPanel", true, false)[0] as UnitSelectionPanel
	panel._show_resists([["Poison", 0.4, Utils.Element.Poison], ["Nova", 0.25, Utils.Element.None]])
	var icons : Array[Node] = panel.resists_row.find_children("*", "TextureRect", true, false)
	kit.check(panel.resists_row.visible and icons.size() == 1 and (icons[0] as TextureRect).texture == UnitSelectionPanel.RESIST_ICONS[Utils.Element.Poison], "the poison drop for Poison, words for the Nova")
	kit.check(panel.resists_row.tooltip_text.begins_with("Resistances"), "the row explains itself")
	panel._show_resists([])
	kit.check(not panel.resists_row.visible, "no row without resistances")
	#through the selection handler: a tower (no resistances) must clear the row, not stop on a typed-array error
	panel._show_resists([["Fire", 0.2, Utils.Element.Fire]])
	var tower : Node2D = Node2D.new()
	panel._on_selected_unit_node(tower)
	kit.check(not panel.resists_row.visible, "selecting a tower hides the row")
	tower.free()
	bottom.queue_free()


func test_pause_menu_shows_the_level(kit : TestKit) -> void:
	var main : Main = load("res://scenes/main.tscn").instantiate()
	kit.root.add_child(main)
	await kit.frames(2)
	UISignals.start_level_button_pressed.emit(6, Utils.LevelMode.Normal)
	for i in 60:
		await kit.frames()
		if main.scene_manager.current_level != null and main.scene_manager.current_level.is_node_ready():
			break
	var pause : PauseMenu = (load("res://scenes/ui/pause_menu/pause_menu.tscn") as PackedScene).instantiate()
	main.ui.add_child(pause)
	var labels : PackedStringArray = []
	for label : Node in pause.find_children("*", "Label", true, false):
		labels.append((label as Label).text)
	var text : String = " | ".join(labels)
	kit.check(text.contains("Bat Roost") and text.contains("Wave 1/5"), "the level and the wave being built for (not a wave 0): %s" % text)
	kit.check(text.contains(PauseMenu.SO_FAR_TEXT) and text.contains(TalentRules.CLEAR_CONDITION_TEXT), "the point checklist")
	pause.queue_free()
	main.queue_free()
	await kit.frames(2)
