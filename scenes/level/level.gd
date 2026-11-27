class_name Level
extends Node2D


const PATH_TO_UNIT_SELECTION_SCENE : String = "res://scenes/unit/unit_selection/unit_selection.tscn"
const WAVE_RUNNER_NAME : String = "WaveRunner"
const BUILDING_TYPE_UPGRADES_NAME : String = "BuildingTypeUpgrades"
const LEVEL_TALENTS_NAME : String = "LevelTalents"
const ELEMENT_REACTIONS_NAME : String = "ElementReactions"
const BUFFER_AURAS_NAME : String = "BufferAuras"
const SYNERGIES_NAME : String = "Synergies"
const MAZE_ELEMENTS_NAME : String = "MazeElements"
const DUST_PUFFS_NAME : String = "DustPuffs"
const HIT_EFFECTS_NAME : String = "HitEffects"
const WALL_GROUP_NAME : String = "WallGroupSelect"
const PATH_PREVIEW_NAME : String = "PathPreview"
const PLAYTEST_LOG_NAME : String = "PlaytestLog"
const BACKDROP_NAME : String = "LevelBackdrop"
const EDGE_FOG_NAME : String = "LevelEdgeFog"
const LAVA_FIELD_NAME : String = "LavaField"
const SANDSTORM_NAME : String = "Sandstorm"
const NO_LEVEL_DATA_WARNING : String = " Level has no LevelData, no waves will spawn!"

@onready var tiles : Tiles = $Tiles
@onready var end_point : Marker2D = $EndPoint
@onready var player_stats : PlayerStats = $PlayerStats

@export var level_data : LevelData = null

## Set by SceneManager before the level enters the tree.
var mode : Utils.LevelMode = Utils.LevelMode.Normal
var mode_data : LevelModeData = null


var grid : LevelGrid = null
var unit_selection : UnitSelection
var upgrades : LevelUpgrades
var building_type_upgrades : BuildingTypeUpgrades
var talents : LevelTalents
var reactions : ElementReactions
var buffer_auras : BufferAuras
## The synergies between buildings (design doc "Synergies", 2026-11-25).
var synergies : Synergies
var wave_runner : WaveRunner
#waves started while enemies of earlier waves were still alive, for the talent points
var early_starts : int = 0
#counts every wave start and every cleared wave, so each wave and each build break is its own round (full sell refunds)
var build_round : int = 0
#an end of wave check waits for the end of the frame (_queue_end_check)
var is_end_check_queued : bool = false
#Survival only: the break between a cleared wave and the next
var survival_break_timer : CustomTimer = null
var all_buildings : Array[Building]
var all_enemies : Array[Enemy]
var existing_enemies : Array[Enemy]
#the living enemies by cell, for each enemy's spacing
var enemy_neighbours : EnemyNeighbours = EnemyNeighbours.new()
#enemies that reached each castle (its end point): a castle with fewer has more of its eggs left
var castle_leaks : Dictionary[Marker2D, int] = {}

#what starting the next wave now pays, only while enemies of the previous waves are alive
var early_start_bonus : float :
	get = _get_early_start_bonus


func _ready() -> void:
	grid = LevelGrid.new(tiles, all_buildings)
	for spawner in get_spawners():
		grid.reserve_cells(spawner.get_footprint_cells(grid))
		for cell in spawner.get_clear_cells(grid):
			grid.spawn_clear_cells[cell] = true
	for child in get_children():
		if child is BogCrossing:
			grid.bog_crossings.append(child)
			#a building on the far shore left waders on the stones standing at the entry for good (2026-11-26)
			grid.unbuildable_cells[grid.world_position_to_grid(child.exit_position)] = true
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
	buffer_auras = BufferAuras.new()
	buffer_auras.name = BUFFER_AURAS_NAME
	add_child(buffer_auras)
	synergies = Synergies.new()
	synergies.name = SYNERGIES_NAME
	add_child(synergies)
	var wall_group : WallGroupSelect = WallGroupSelect.new()
	wall_group.name = WALL_GROUP_NAME
	add_child(wall_group)
	var maze_elements : MazeElements = MazeElements.new()
	maze_elements.name = MAZE_ELEMENTS_NAME
	add_child(maze_elements)
	var dust_puffs : DustPuffs = DustPuffs.new()
	dust_puffs.name = DUST_PUFFS_NAME
	add_child(dust_puffs)
	var hit_effects : HitEffects = HitEffects.new()
	hit_effects.name = HIT_EFFECTS_NAME
	add_child(hit_effects)
	var backdrop : LevelBackdrop = LevelBackdrop.new()
	backdrop.name = BACKDROP_NAME
	add_child(backdrop)
	var edge_fog : LevelEdgeFog = LevelEdgeFog.new()
	edge_fog.name = EDGE_FOG_NAME
	edge_fog.playfield = grid.get_playfield_rect()
	add_child(edge_fog)
	_setup_scorched_lands()
	var path_preview : PathPreview = PathPreview.new()
	path_preview.name = PATH_PREVIEW_NAME
	add_child(path_preview)
	var hover_info : EnemyHoverInfo = EnemyHoverInfo.new()
	hover_info.name = EnemyHoverInfo.NODE_NAME
	add_child(hover_info)
	#last: it reads the start gold after the talents
	var playtest_log : PlaytestLog = PlaytestLog.new()
	playtest_log.name = PLAYTEST_LOG_NAME
	add_child(playtest_log)
	UISignals.start_wave_pressed.connect(_on_start_wave_pressed)
	UISignals.game_play_interface_loaded.connect(_emit_wave_state)
	GameSignals.level_loaded.emit(self)


#the volcano's lava and fissures, the desert's sandstorms (LevelData's Scorched Lands group)
func _setup_scorched_lands() -> void:
	var has_fissure : bool = get_children().any(func(child : Node) -> bool: return child is Fissure)
	if level_data != null and (level_data.lava_cools or has_fissure):
		var lava_field : LavaField = LavaField.new()
		lava_field.name = LAVA_FIELD_NAME
		add_child(lava_field)
	if level_data != null and level_data.sandstorm_every > 0.0:
		var sandstorm : Sandstorm = Sandstorm.new()
		sandstorm.name = SANDSTORM_NAME
		sandstorm.every = level_data.sandstorm_every
		add_child(sandstorm)


## Every castle of the level (its end point and the spawners' ones), each once.
func get_castles() -> Array[Marker2D]:
	var castles : Array[Marker2D] = [end_point]
	for spawner in get_spawners():
		if spawner.end_point != null and not castles.has(spawner.end_point):
			castles.append(spawner.end_point)
	return castles


## The castle with the most eggs left: the fewest enemies have reached it (the first on a tie).
func get_fullest_castle() -> Marker2D:
	var best : Marker2D = null
	for castle in get_castles():
		if best == null or castle_leaks.get(castle, 0) < castle_leaks.get(best, 0):
			best = castle
	return best


func _exit_tree() -> void:
	GameSignals.game_stop.emit()


func _on_enemy_spawned(enemy : Enemy) -> void:
	#a boss's health is set by hand, so the level's wave ramp leaves it alone (Hard mode still scales it)
	var level_wave_count : int = wave_runner.waves.size()
	var level_wave_index : int = maxi(wave_runner.current_wave_index, 0) % maxi(level_wave_count, 1)
	if level_data != null and not enemy.is_boss:
		LevelModeData.scale_health(enemy, level_data.get_wave_health(level_wave_index, level_wave_count))
	elif level_data != null:
		#a boss skips the wave ramp but follows the level's tuned strength
		LevelModeData.scale_health(enemy, level_data.health_scale)
	if mode_data != null:
		mode_data.apply_to_enemy(enemy, level_wave_index, level_wave_count)
	if mode == Utils.LevelMode.Hard and level_data != null:
		LevelModeData.scale_health(enemy, level_data.hard_health_scale)
	#Survival: every loop of the waves is tougher and pays more
	if wave_runner.is_endless:
		LevelModeData.scale_health(enemy, SurvivalRules.health_multiplier(wave_runner.wave_number, level_wave_count))
		var gold_multiplier : float = SurvivalRules.gold_multiplier(wave_runner.wave_number, level_wave_count)
		if not is_equal_approx(gold_multiplier, 1.0):
			enemy.modifier_manager.add_modifier(Elite.multiply(Utils.StatType.Price, gold_multiplier))
	EnemyHealthBar.attach(enemy)
	all_enemies.append(enemy)
	existing_enemies.append(enemy)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	existing_enemies.erase(enemy)
	_queue_end_check()


func _on_enemy_reached_end(enemy : Enemy) -> void:
	existing_enemies.erase(enemy)
	if enemy.end_point != null:
		castle_leaks[enemy.end_point] = castle_leaks.get(enemy.end_point, 0) + 1
	_queue_end_check()


#checked once at the end of the frame: what a death leaves behind (a phoenix's rebirth, a splitting elite's copies,
#a golem's blobs) is spawned by handlers that run after this node's, and several deaths and leaks in one frame
#must clear the wave only once
func _queue_end_check() -> void:
	if is_end_check_queued:
		return
	is_end_check_queued = true
	_run_queued_end_check.call_deferred()


func _run_queued_end_check() -> void:
	is_end_check_queued = false
	_check_level_end_conditions()


func _on_building_placed(building : Building) -> void:
	all_buildings.append(building)
	grid.mark_buildings_changed()
	GameSignals.astar_grid_updated.emit()


func _on_building_erase(building : Building) -> void:
	all_buildings.erase(building)
	grid.mark_buildings_changed()
	GameSignals.astar_grid_updated.emit()


## The buildings on the map that raise the next one's price (the towers).
func get_price_step_count() -> int:
	var count : int = 0
	for building in all_buildings:
		if is_instance_valid(building) and building.price_step > 0.0:
			count += 1
	return count


## Sets a not yet placed building's price to its base plus the step for every stepped building on the map.
## Called on the build ghost whenever the count changes and on a new building before place(), which pays it.
func apply_price_step(building : Building) -> void:
	if building.price_step <= 0.0:
		return

	if building.price_step_modifier != null:
		building.modifier_manager.remove_modifier(building.price_step_modifier)

	var modifier : ModifierData = ModifierData.new()
	modifier.modifier_type = Utils.ModifierType.StatModifier
	modifier.calculate_type = Utils.ModifyType.Flat
	modifier.stat_type = Utils.StatType.Price
	modifier.value = UpgradeRules.price_step_extra(building.price_step, get_price_step_count())
	building.price_step_modifier = modifier
	building.modifier_manager.add_modifier(modifier)


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
	
	build_round += 1
	GameSignals.wave_cleared.emit(wave_runner.wave_number)
	_emit_wave_state()
	if survival_break_timer != null:
		survival_break_timer.start()


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
	mode_data = level_data.get_mode_data(mode)
	var waves : Array[WaveData] = level_data.waves if mode_data == null else mode_data.get_waves(level_data.waves)
	wave_runner.setup(waves, get_spawners())
	wave_runner.is_endless = mode == Utils.LevelMode.Survival
	if wave_runner.is_endless:
		#non-stop: a cleared wave starts the next one after a short break
		survival_break_timer = CustomTimer.new()
		survival_break_timer.one_shot = true
		add_child(survival_break_timer)
		survival_break_timer.unscaled_base_value = SurvivalRules.BREAK_SECONDS
		survival_break_timer.timeout.connect(_on_start_wave_pressed)


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
	
	if survival_break_timer != null:
		survival_break_timer.stop()
	#read before starting, the bonus depends on the wave that comes next
	var bonus : float = early_start_bonus
	var is_early : bool = not existing_enemies.is_empty()
	build_round += 1
	wave_runner.start_next_wave()
	
	if bonus > 0.0:
		player_stats.add_gold(bonus)

	if is_early:
		early_starts += 1
	
	_emit_wave_state()


func _on_wave_spawning_finished() -> void:
	_emit_wave_state()
	_queue_end_check()


func _emit_wave_state() -> void:
	GameSignals.wave_state_changed.emit(wave_runner.wave_number, wave_runner.wave_count, wave_runner.can_start_next_wave, early_start_bonus)


func _get_unit_selection() -> void:
	if unit_selection == null:
		if has_node("UnitSelection"):
			unit_selection = get_node("UnitSelection")
		else:
			#a level scene without one gets its own; out of the tree it would never select and leak
			unit_selection = ResourceLoader.load(PATH_TO_UNIT_SELECTION_SCENE).instantiate()
			add_child(unit_selection)


func _get_early_start_bonus() -> float:
	if existing_enemies.is_empty() or wave_runner.next_wave == null:
		return 0.0
	
	#Bold Start (talent) raises it
	var talent_bonus : float = talents.get_total(TalentEffect.Kind.EarlyStartBonus) if talents != null else 0.0
	return wave_runner.next_wave.early_start_bonus * (1.0 + talent_bonus)
