extends RefCounted

## A player's clicks through the real Main and selection card (bug search 2026-11-25): every building type on the
## last level, selected, upgraded through its buttons until none is left (tiers too, every talent learned), its
## Target menu and Rally button used, then sold, while a wave runs. The bots buy through BuildingTypeUpgrades
## itself, so this is the only run through the card's buttons.

const LEVEL_NUMBER : int = 60
const GOLD : float = 99999.0
const BUILDINGS : Array[String] = ["puffe_bolter", "puffe_nova", "puffe_beamer", "puffe_mortar", "puffe_buffer", "puffe_breather",
	"puffe_spotter", "puffe_harpooner", "puffe_hatchery", "puffe_shredder", "puffe_elder", "puffe_hoard", "leopard_trap", "egg_bomb",
	"spike_field", "wall"]
const TRAPS : Array[String] = ["leopard_trap", "egg_bomb", "spike_field"]
const TALENT_BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")
#more presses than any building has steps: the loop stops when no button is left to press
const MOST_PRESSES : int = 30


func test_every_building_through_the_card(kit : TestKit) -> void:
	for tree in TALENT_BOOK.trees:
		for node in tree.nodes:
			PlayerProgress.set_talent_rank(tree.id, node.id, node.max_rank)
	var main : Main = load("res://scenes/main.tscn").instantiate()
	kit.root.add_child(main)
	await kit.frames(2)
	UISignals.start_level_button_pressed.emit(LEVEL_NUMBER, Utils.LevelMode.Normal)
	var level : Level = null
	for i in 600:
		await kit.frames()
		level = main.scene_manager.current_level as Level
		if level != null and level.is_node_ready():
			break
	kit.check(level != null, "the level loads")
	if level == null:
		main.queue_free()
		return
	kit.level = level
	await kit.frames(2)
	var panel : UnitSelectionPanel = main.find_children("*", "UnitSelectionPanel", true, false)[0]
	level.player_stats.gold = GOLD
	level.player_stats.life = 999.0
	UISignals.start_wave_pressed.emit()

	var on_route : Dictionary[Vector2i, bool] = {}
	var route_cells : Array[Vector2i] = []
	for route in level.get_routes():
		for point in level.grid.find_path(route[0], route[1]):
			var cell : Vector2i = level.grid.world_position_to_grid(point)
			on_route[cell] = true
			route_cells.append(cell)
	for building_name in BUILDINGS:
		level.player_stats.gold = GOLD
		var cell : Vector2i = _free_cell(kit, building_name in TRAPS, on_route, route_cells)
		kit.check(cell != Vector2i.MAX, "a cell for %s" % building_name)
		if cell == Vector2i.MAX:
			continue
		var building : Building = await kit.place(building_name, cell)
		GameSignals.forced_selection.emit(building)
		await kit.frames(2)
		kit.check(panel.visible and not panel.name_value.text.is_empty(), "%s: the card shows" % building_name)
		var presses : int = await _press_every_upgrade(kit, panel)
		kit.check(presses > 0 or building is HoardKeeper, "%s: upgrades bought through the card (%d)" % [building_name, presses])
		#every talent learned: the element and both tiers come up and get bought
		if not building is Wall:
			kit.check(building.evolve_tree != null and building.evolve_tree.tier >= 3, "%s: up to T3 through the card (tier %d, %d presses)"
				% [building_name, building.evolve_tree.tier if building.evolve_tree != null else -1, presses])
		if panel.tactic_row.visible:
			for index in panel.tactic_menu.item_count:
				panel.tactic_menu.select(index)
				panel.tactic_menu.item_selected.emit(index)
				await kit.frames(1)
				kit.check(building.target_tactic == panel.tactic_menu.get_item_id(index), "%s: the Target menu sets the tactic" % building_name)
		if building is Hatchery:
			kit.check(panel.rally_button.visible, "the Hatchery shows its Rally button")
			panel.rally_button.pressed.emit()
			await kit.frames(1)
			kit.check((building as Hatchery).is_picking_rally, "Rally starts the pick")
			#sold while picking: nothing may wait on it afterwards
		panel.sell_button.pressed.emit()
		await kit.frames(3)
		kit.check(not is_instance_valid(building) or building.is_queued_for_deletion() or not building.is_placed, "%s: sold" % building_name)
		#a few seconds of the wave between buildings: shots, effects and abilities around the sold one
		await kit.run_until(func() -> bool: return false, 3.0)
	#a level-up offer or a lost level pauses the tree: later tests need it running, at normal speed
	main.reset_time_scale()
	kit.root.get_tree().paused = false
	main.queue_free()
	await kit.frames(2)


#presses the first enabled, unlocked upgrade button until none is left
func _press_every_upgrade(kit : TestKit, panel : UnitSelectionPanel) -> int:
	var presses : int = 0
	for i in MOST_PRESSES:
		var pressed : bool = false
		for child in panel.upgrade_option_container.get_children():
			var button : Button = child as Button
			if button != null and not button.disabled and not button.is_queued_for_deletion() and button.icon != UnitSelectionPanel.LOCKED_ICON:
				button.pressed.emit()
				presses += 1
				pressed = true
				break
		await kit.frames(1)
		if not pressed:
			break
	return presses


func _free_cell(kit : TestKit, is_trap : bool, on_route : Dictionary[Vector2i, bool], route_cells : Array[Vector2i]) -> Vector2i:
	var grid : LevelGrid = kit.level.grid
	if is_trap:
		for cell in route_cells.slice(6):
			if grid.is_position_buildable(grid.grid_position_to_world(cell)) and not grid.has_building_in_cell_position(cell):
				return cell
		return Vector2i.MAX
	var near : Vector2i = route_cells[mini(8, route_cells.size() - 1)]
	return kit.find_cell(func(cell : Vector2i) -> bool:
		return not on_route.has(cell) and Vector2(cell - near).length() <= 3.0 \
			and grid.is_position_buildable(grid.grid_position_to_world(cell)) and not grid.has_building_in_cell_position(cell))
