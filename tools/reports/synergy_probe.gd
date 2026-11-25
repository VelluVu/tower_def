extends RefCounted

## Sets synergy partners up in a real game (Main, walking enemies, every talent learned) and reports how often each
## synergy fired (Synergies.counts). Built for the bug search 2026-11-25 (synergies the bots never set off).
## `python tools/gd.py run tools/reports/synergy_probe.gd level=14 build=leopard_trap,egg_bomb+side seconds=60 --raw`
##   build=  buildings in order: traps go on route cells one after another (beside each other), towers on free cells
##           near the first trap; name:Element:tier buys upgrades up to that element and tier (tier 1 = the element,
##           3 = T3); +side puts a trap on a walkable cell beside the first trap, off the route
##   seconds=60 game seconds in all; waves=1 waves started over them; first=6 route cells skipped before the first trap

const MAIN_SCENE : String = "res://scenes/main.tscn"
const TRAPS : Array[String] = ["leopard_trap", "egg_bomb", "spike_field"]
const TALENT_BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")
const MOST_BUYS : int = 30

var options : Dictionary[String, String] = {"level": "14", "build": "leopard_trap,egg_bomb", "seconds": "60", "first": "6"}


func run(kit : TestKit, args : PackedStringArray) -> void:
	for arg in args:
		var parts : PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	for tree in TALENT_BOOK.trees:
		for node in tree.nodes:
			PlayerProgress.set_talent_rank(tree.id, node.id, node.max_rank)
	var main : Main = load(MAIN_SCENE).instantiate()
	kit.root.add_child(main)
	await kit.frames(2)
	UISignals.start_level_button_pressed.emit(int(options.level), Utils.LevelMode.Normal)
	var level : Level = null
	for i in 600:
		await kit.frames()
		level = main.scene_manager.current_level as Level
		if level != null and level.is_node_ready():
			break
	kit.level = level
	await kit.frames(2)
	level.player_stats.gold = 99999.0
	level.player_stats.life = 999.0

	var cells : Array[Vector2i] = _route_cells(kit)
	var at : int = int(options.first)
	while at < cells.size() - 1 and maxi(absi(cells[at].x - cells[at + 1].x), absi(cells[at].y - cells[at + 1].y)) > 1:
		at += 1
	var first_trap : Vector2i = cells[at]
	var placed : Array[Building] = []
	for item in options.build.split(",", false):
		var spec : PackedStringArray = item.split("+")[0].split(":")
		var cell : Vector2i = Vector2i.MAX
		if item.ends_with("+side"):
			cell = _side_cell(kit, first_trap)
		elif spec[0] in TRAPS:
			cell = cells[at]
			at += 1
		else:
			cell = _cell_near(kit, first_trap)
		var building : Building = await kit.place(spec[0], cell)
		if spec.size() >= 3:
			_buy_up_to(level, building, spec[1], int(spec[2]))
		placed.append(building)
		print("PROBE %s at %s, element %s tier %d" % [building.name, cell, _element(building), building.evolve_tree.tier if building.evolve_tree != null else -1])
	#waves=N: the next wave every seconds/N, early when needed
	var waves : int = int(options.get("waves", "1"))
	for wave in waves:
		UISignals.start_wave_pressed.emit()
		#a level-up offer pauses the game: take the first card, as a player would take one
		await kit.run_until(func() -> bool:
			if not level.upgrades.offered_cards.is_empty():
				level.upgrades._on_upgrade_card_selected(0)
			return false, float(options.seconds) / waves)
	print("PROBE synergies %s" % level.synergies.counts)
	main.reset_time_scale()
	main.get_tree().paused = false
	main.queue_free()
	await kit.frames(2)


#the element's leaf first, then every other step, until the tier is reached
func _buy_up_to(level : Level, building : Building, element_name : String, tier : int) -> void:
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	for i in MOST_BUYS:
		if building.evolve_tree.tier >= tier:
			return
		upgrades._on_unit_selected(building)
		var pick : int = -1
		for index in upgrades.options.size():
			var option : GoldUpgradeOption = upgrades.options[index]
			if option.is_locked:
				continue
			if option.is_choice and not str(option.element_leaf_path).get_file().begins_with(element_name):
				continue
			pick = index
			break
		if pick < 0:
			return
		upgrades._on_gold_upgrade_pressed(pick)


func _element(building : Building) -> String:
	if building.evolve_tree == null or not building.evolve_tree.is_element_chosen:
		return "-"
	return Utils.Element.find_key(building.evolve_tree.evolve_element)


func _on_route(kit : TestKit) -> Dictionary[Vector2i, bool]:
	var on_route : Dictionary[Vector2i, bool] = {}
	for route in kit.level.get_routes():
		for point in kit.level.grid.find_path(route[0], route[1]):
			on_route[kit.level.grid.world_position_to_grid(point)] = true
	return on_route


func _is_free(kit : TestKit, cell : Vector2i) -> bool:
	return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(cell)) and not kit.level.grid.has_building_in_cell_position(cell)


func _side_cell(kit : TestKit, cell : Vector2i) -> Vector2i:
	var on_route : Dictionary[Vector2i, bool] = _on_route(kit)
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var side : Vector2i = cell + offset
		if not on_route.has(side) and kit.level.grid.is_cell_walkable(side) and _is_free(kit, side):
			return side
	return cell


func _cell_near(kit : TestKit, near : Vector2i) -> Vector2i:
	var on_route : Dictionary[Vector2i, bool] = _on_route(kit)
	var best : Vector2i = Vector2i.MAX
	var region : Rect2i = kit.level.grid.astar_grid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell : Vector2i = Vector2i(x, y)
			if not on_route.has(cell) and _is_free(kit, cell) \
					and (best == Vector2i.MAX or Vector2(cell - near).length() < Vector2(best - near).length()):
				best = cell
	return best


func _route_cells(kit : TestKit) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	var route : PackedVector2Array = kit.level.get_routes()[0]
	for point in kit.level.grid.find_path(route[0], route[1]).slice(int(options.first)):
		var cell : Vector2i = kit.level.grid.world_position_to_grid(point)
		if _is_free(kit, cell):
			cells.append(cell)
	return cells
