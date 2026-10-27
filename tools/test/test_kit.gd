class_name TestKit
extends RefCounted

## Helpers for headless tests and reports (run them with `python tools/gd.py`).
## Stands in for Main so levels, buildings and enemies work without the menu flow.

const LEVEL_PATH : String = "res://scenes/level/levels/level_%03d.tscn"
const LEVEL_DATA_PATH : String = "res://scenes/level/level_data/level_%03d_data.tres"
const BUILDING_PATH : String = "res://scenes/unit/building/buildings/%s.tscn"
const ENEMY_PATH : String = "res://scenes/unit/enemy/enemies/%s.tscn"
const CARD_PATH : String = "res://scenes/unit/evolve_tree/evolve_resources/%s.tres"
#Builder puts placed buildings in this container; Building.level is its parent
const BUILDINGS_NODE_NAME : String = "Buildings"
const TEST_SAVE_PATH : String = "user://test_progress.tres"
const TEST_PLAYTEST_LOG_PATH : String = "user://bot_playtests.jsonl"

var root : Node = null
var level : Level = null
var failures : PackedStringArray = []
var checks : int = 0


func _init(test_root : Node) -> void:
	root = test_root
	#a test that saves progress must never overwrite the player's own save
	PlayerProgress._save.save_path = TEST_SAVE_PATH
	#tests leave no playtest lines; the soak bot turns its own log back on
	PlaytestLog.is_enabled = false
	PlaytestLog.log_path = TEST_PLAYTEST_LOG_PATH
	var main : Main = Main.new()
	main.scene_manager = SceneManager.new()
	Utils.game_control = main


func load_level(number : int) -> Level:
	free_level()
	level = load(LEVEL_PATH % number).instantiate()
	root.add_child(level)
	Utils.game_control.scene_manager.current_level = level
	Utils.game_control.scene_manager.current_level_number = number
	await root.get_tree().process_frame
	return level


func free_level() -> void:
	if level == null:
		return
	level.free()
	level = null


func level_data(number : int) -> LevelData:
	return load(LEVEL_DATA_PATH % number)


## Places a building ("wall", "puffe_bolter", ...) in a cell like the Builder does.
func place(building_name : String, cell : Vector2i) -> Building:
	var building : Building = load(BUILDING_PATH % building_name).instantiate()
	_get_buildings_container().add_child(building)
	await root.get_tree().process_frame
	building.place(level.grid.grid_position_to_world(cell))
	await root.get_tree().process_frame
	return building


## Spawns an enemy ("weakling", ...) at a spawner, walking to its castle.
func spawn_enemy(enemy_name : String, spawner_index : int = 0) -> Enemy:
	var spawner : Spawner = level.get_spawners()[spawner_index]
	var enemy : Enemy = load(ENEMY_PATH % enemy_name).instantiate()
	enemy.end_point = spawner.end_point
	enemy.global_position = spawner.global_position
	level.add_child(enemy)
	return enemy


## Picks a card as if it was offered and chosen; value defaults to the card's base value.
func pick_card(card_name : String, value : float = NAN) -> UpgradeCard:
	var resource : EvolveResource = load(CARD_PATH % card_name)
	var card : UpgradeCard = UpgradeCard.from_resource(resource, resource.modify_value if is_nan(value) else value)
	level.upgrades.offered_cards = [card]
	level.upgrades.pending_level_ups = 1
	level.upgrades._on_upgrade_card_selected(0)
	return card


## Steps physics frames until condition returns true or seconds of game time pass; returns the time taken.
func run_until(condition : Callable, seconds : float) -> float:
	var time : float = 0.0
	while time < seconds and not condition.call():
		await root.get_tree().physics_frame
		time += root.get_physics_process_delta_time()
	return time


func frames(count : int = 1) -> void:
	for i in count:
		await root.get_tree().process_frame


func check(condition : bool, message : String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func check_near(actual : float, expected : float, message : String, tolerance : float = 0.001) -> void:
	check(absf(actual - expected) <= tolerance, "%s: expected %s, got %s" % [message, expected, actual])


## A walkable cell on the level for which filter(cell) is true, or Vector2i.MAX.
func find_cell(filter : Callable) -> Vector2i:
	var region : Rect2i = level.grid.astar_grid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell : Vector2i = Vector2i(x, y)
			if level.grid.is_cell_walkable(cell) and filter.call(cell):
				return cell
	return Vector2i.MAX


func _get_buildings_container() -> Node2D:
	if level.has_node(BUILDINGS_NODE_NAME):
		return level.get_node(BUILDINGS_NODE_NAME)
	var container : Node2D = Node2D.new()
	container.name = BUILDINGS_NODE_NAME
	level.add_child(container)
	return container
