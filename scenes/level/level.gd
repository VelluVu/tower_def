class_name Level
extends Node2D


const PATH_TO_UNIT_SELECTION_SCENE : String = "res://scenes/unit/unit_selection/unit_selection.tscn"
const WAVE_RUNNER_NAME : String = "WaveRunner"
const BUILDING_TYPE_UPGRADES_NAME : String = "BuildingTypeUpgrades"
const LEVEL_TALENTS_NAME : String = "LevelTalents"
const ELEMENT_REACTIONS_NAME : String = "ElementReactions"
const PATH_PREVIEW_NAME : String = "PathPreview"
const PLAYTEST_LOG_NAME : String = "PlaytestLog"
const BACKDROP_NAME : String = "LevelBackdrop"
const EDGE_FOG_NAME : String = "LevelEdgeFog"
const NO_LEVEL_DATA_WARNING : String = " Level has no LevelData, no waves will spawn!"

@onready var tiles : Tiles = $Tiles
@onready var end_point : Marker2D = $EndPoint
@onready var player_stats : PlayerStats = $PlayerStats

@export var level_data : LevelData = null


var grid : LevelGrid = null
var unit_selection : UnitSelection
var upgrades : LevelUpgrades
var building_type_upgrades : BuildingTypeUpgrades
var talents : LevelTalents
var reactions : ElementReactions
var wave_runner : WaveRunner
#waves started while enemies of earlier waves were still alive, for the talent points
var early_starts : int = 0
var all_buildings : Array[Building]
var all_enemies : Array[Enemy]
var existing_enemies : Array[Enemy]

#what starting the next wave now pays, only while enemies of the previous waves are alive
var early_start_bonus : float :
	get = _get_early_start_bonus


func _ready() -> void:
	grid = LevelGrid.new(tiles, all_buildings)
	for spawner in get_spawners():
		grid.reserve_cells(spawner.get_footprint_cells(grid))
	GameSignals.astar_grid_updated.emit()
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.building_destroyed.connect(_on_building_erase)
	GameSignals.sell_building.connect(_on_building_erase)
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reached_end)
	_get_unit_selection()
	#before LevelUpgrades: both handle building_placed, and the element must be applied before the cards
	building_type_upgrades = BuildingTypeUpgrades.new()
	building_type_upgrades.name = BUILDING_TYPE_UPGRADES_NAME
	add_child(building_type_upgrades)
	upgrades = LevelUpgrades.new()
	upgrades.name = "LevelUpgrades"
	add_child(upgrades)
	_setup_waves()
	#after the waves: the level data sets the start gold, the talents add to it
	talents = LevelTalents.new()
	talents.name = LEVEL_TALENTS_NAME
	add_child(talents)
	reactions = ElementReactions.new()
	reactions.name = ELEMENT_REACTIONS_NAME
	add_child(reactions)
	var backdrop : LevelBackdrop = LevelBackdrop.new()
	backdrop.name = BACKDROP_NAME
	add_child(backdrop)
	var edge_fog : LevelEdgeFog = LevelEdgeFog.new()
	edge_fog.name = EDGE_FOG_NAME
	edge_fog.playfield = grid.get_playfield_rect()
	add_child(edge_fog)
	var path_preview : PathPreview = PathPreview.new()
	path_preview.name = PATH_PREVIEW_NAME
	add_child(path_preview)
	#last: it reads the start gold after the talents
	var playtest_log : PlaytestLog = PlaytestLog.new()
	playtest_log.name = PLAYTEST_LOG_NAME
	add_child(playtest_log)
	UISignals.start_wave_pressed.connect(_on_start_wave_pressed)
	UISignals.game_play_interface_loaded.connect(_emit_wave_state)
	GameSignals.level_loaded.emit(self)


func _exit_tree() -> void:
	GameSignals.game_stop.emit()


func _on_enemy_spawned(enemy : Enemy) -> void:
	all_enemies.append(enemy)
	existing_enemies.append(enemy)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	existing_enemies.erase(enemy)
	_check_level_end_conditions()


func _on_enemy_reached_end(enemy : Enemy) -> void:
	existing_enemies.erase(enemy)
	_check_level_end_conditions()


func _on_building_placed(building : Building) -> void:
	all_buildings.append(building)
	GameSignals.astar_grid_updated.emit()


func _on_building_erase(building : Building) -> void:
	all_buildings.erase(building)
	GameSignals.astar_grid_updated.emit()


func _check_level_end_conditions() -> void:
	if not existing_enemies.is_empty() or wave_runner.is_spawning or wave_runner.wave_number == 0:
		return
	
	if not player_stats.is_alive:
		#otherwise the wave panel keeps the early start bonus of the lost wave
		_emit_wave_state()
		return

	if wave_runner.is_last_wave_started:
		GameSignals.level_completed.emit(self)
		return
	
	GameSignals.wave_cleared.emit(wave_runner.wave_number)
	_emit_wave_state()


func _setup_waves() -> void:
	wave_runner = WaveRunner.new()
	wave_runner.name = WAVE_RUNNER_NAME
	add_child(wave_runner)
	wave_runner.spawning_finished.connect(_on_wave_spawning_finished)
	
	if level_data == null:
		push_warning(name, NO_LEVEL_DATA_WARNING)
		return
	
	player_stats.gold = level_data.starting_gold
	player_stats.life = level_data.starting_life
	wave_runner.setup(level_data.waves, get_spawners())


## The area the enemies cross: every spawner and end point, for framing the camera.
func get_path_bounds() -> Rect2:
	var bounds : Rect2 = Rect2(end_point.global_position, Vector2.ZERO)

	for spawner in get_spawners():
		bounds = bounds.expand(spawner.global_position)
		if spawner.end_point != null:
			bounds = bounds.expand(spawner.end_point.global_position)

	return bounds


func get_spawners() -> Array[Spawner]:
	var spawners : Array[Spawner] = []

	for node in get_tree().get_nodes_in_group(GroupNames.SPAWNER):
		if node is Spawner and is_ancestor_of(node):
			spawners.append(node)

	return spawners


#each spawner's start and end point, the routes enemies walk
func get_routes() -> Array[PackedVector2Array]:
	var routes : Array[PackedVector2Array] = []

	for spawner in get_spawners():
		var end : Vector2 = spawner.end_point.global_position if spawner.end_point != null else end_point.global_position
		routes.append(PackedVector2Array([spawner.global_position, end]))

	return routes


func _on_start_wave_pressed() -> void:
	if not wave_runner.can_start_next_wave:
		return
	
	#read before starting, the bonus depends on the wave that comes next
	var bonus : float = early_start_bonus
	var is_early : bool = not existing_enemies.is_empty()
	wave_runner.start_next_wave()
	
	if bonus > 0.0:
		player_stats.add_gold(bonus)

	if is_early:
		early_starts += 1
	
	_emit_wave_state()


func _on_wave_spawning_finished() -> void:
	_emit_wave_state()
	_check_level_end_conditions()


func _emit_wave_state() -> void:
	GameSignals.wave_state_changed.emit(wave_runner.wave_number, wave_runner.wave_count, wave_runner.can_start_next_wave, early_start_bonus)


func _get_unit_selection() -> void:
	if unit_selection == null:
		if has_node("UnitSelection"):
			unit_selection = get_node("UnitSelection")
		else:
			unit_selection = ResourceLoader.load(PATH_TO_UNIT_SELECTION_SCENE).instantiate()


func _get_early_start_bonus() -> float:
	if existing_enemies.is_empty() or wave_runner.next_wave == null:
		return 0.0
	
	return wave_runner.next_wave.early_start_bonus
