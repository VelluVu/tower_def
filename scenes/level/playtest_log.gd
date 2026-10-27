class_name PlaytestLog
extends Node

## Writes one line per level run (won, lost, resigned or left) to a JSON lines file, so playtests
## can be compared and the balance tuned from real numbers (`python tools/playtests.py`). Debug
## builds only. Created by the Level, after the talents have added their start gold.

const LOG_PATH : String = "user://playtests.jsonl"
const MODE_NORMAL : String = "normal"
const PLAYER : String = "player"
const RESULT_WON : String = "won"
const RESULT_LOST : String = "lost"
const RESULT_RESIGNED : String = "resigned"
const RESULT_LEFT : String = "left"
const UPGRADES_KEY : String = "upgrades"
const DIGITS : String = "0123456789"
const OPEN_ERROR : String = " Could not open the playtest log: "

## Tests and the soak bot write to their own file and name who played.
static var log_path : String = LOG_PATH
static var player : String = PLAYER
static var is_enabled : bool = OS.is_debug_build()

var start_msec : int = 0
var game_seconds : float = 0.0
var current_time_scale : float = 1.0
var max_time_scale : float = 1.0
var start_gold : float = 0.0
var start_life : float = 0.0
var last_gold : float = 0.0
var gold_earned : float = 0.0
var gold_spent : float = 0.0
#building type -> gold spent placing them
var placing_spent : Dictionary[String, float] = {}
var placed : Dictionary[String, int] = {}
var sold : int = 0
var destroyed : int = 0
var killed : int = 0
var leaked : Dictionary[String, int] = {}
var life_by_wave : Array[float] = []
var gold_by_wave : Array[float] = []
var used_cheats : bool = false
var is_written : bool = false

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level


func _ready() -> void:
	start_msec = Time.get_ticks_msec()
	start_gold = level.player_stats.gold
	start_life = level.player_stats.life
	last_gold = start_gold
	used_cheats = GameSignals.developer_mode
	if Utils.game_control != null:
		current_time_scale = Utils.game_control.time_scale

	GameSignals.resource_change.connect(_on_resource_change)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(func(_building : Building) -> void: sold += 1)
	GameSignals.building_destroyed.connect(func(_building : Building) -> void: destroyed += 1)
	GameSignals.enemy_destroyed.connect(func(_enemy : Enemy) -> void: killed += 1)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reached_end)
	GameSignals.wave_cleared.connect(_on_wave_cleared)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	GameSignals.developer_mode_changed.connect(_on_developer_mode_changed)
	GameSignals.level_completed.connect(func(_level : Level) -> void: _write(RESULT_WON))
	GameSignals.lose_game.connect(func() -> void: _write(RESULT_LOST))
	UISignals.resign_level.connect(func() -> void: _write(RESULT_RESIGNED))


func _process(delta : float) -> void:
	if not get_tree().paused:
		game_seconds += delta * current_time_scale


func _exit_tree() -> void:
	_write(RESULT_LEFT)


func _on_resource_change(_value : int, resource_index : int) -> void:
	if resource_index != 0:
		return

	var gold : float = level.player_stats.gold
	if gold > last_gold:
		gold_earned += gold - last_gold
	else:
		gold_spent += last_gold - gold
	last_gold = gold


func _on_building_placed(building : Building) -> void:
	var type : String = _building_type(building)
	placed[type] = placed.get(type, 0) + 1
	if not GameSignals.free_build:
		placing_spent[type] = placing_spent.get(type, 0.0) + building.stats.get_stat_value(Utils.StatType.Price)


func _on_enemy_reached_end(enemy : Enemy) -> void:
	var type : String = String(enemy.name).rstrip(DIGITS)
	leaked[type] = leaked.get(type, 0) + 1


func _on_wave_cleared(_wave_number : int) -> void:
	life_by_wave.append(level.player_stats.life)
	gold_by_wave.append(level.player_stats.gold)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	max_time_scale = maxf(max_time_scale, time_scale)


func _on_developer_mode_changed(is_enabled_now : bool) -> void:
	used_cheats = used_cheats or is_enabled_now


func _write(result : String) -> void:
	if is_written or not is_enabled:
		return
	is_written = true

	#opening a level and leaving before the first wave is not a playtest (the load check does this too)
	if level.wave_runner.wave_number == 0:
		return

	var file : FileAccess = _open_for_append()
	if file == null:
		return
	file.store_line(JSON.stringify(_record(result)))
	file.close()


func _record(result : String) -> Dictionary:
	var is_won : bool = result == RESULT_WON
	if is_won:
		life_by_wave.append(level.player_stats.life)
		gold_by_wave.append(level.player_stats.gold)

	var spent_on : Dictionary = placing_spent.duplicate()
	var placing_total : float = 0.0
	for type in placing_spent:
		placing_total += placing_spent[type]
	spent_on[UPGRADES_KEY] = maxf(gold_spent - placing_total, 0.0)

	var buildings : Dictionary[String, int] = {}
	var elements : Dictionary[String, String] = {}
	var upgrades : Dictionary[String, int] = {}
	for building in level.all_buildings:
		if not is_instance_valid(building):
			continue
		var type : String = _building_type(building)
		buildings[type] = buildings.get(type, 0) + 1
		if building.evolve_tree != null and building.evolve_tree.evolve_element != Utils.Element.Physical:
			elements[type] = Utils.Element.find_key(building.evolve_tree.evolve_element)
		var state : BuildingTypeUpgrades.UpgradeState = level.building_type_upgrades.building_states.get(building)
		if state != null:
			upgrades[type] = upgrades.get(type, 0) + state.upgrades_bought + state.tiers_evolved
	#per-type buildings (walls) share one state
	for type_path in level.building_type_upgrades.type_states:
		var type_state : BuildingTypeUpgrades.UpgradeState = level.building_type_upgrades.type_states[type_path]
		upgrades[type_path.get_file().get_basename()] = type_state.upgrades_bought + type_state.tiers_evolved

	var cards : Array[String] = []
	for card in level.upgrades.chosen_cards:
		cards.append("%s %s" % [card.title, snappedf(card.value, 0.01)])

	var talents : Dictionary[String, int] = {}
	for tree_id in [&"building", &"fire", &"frost", &"poison"]:
		var spent : int = TalentRules.get_spent(PlayerProgress.get_talent_ranks(tree_id))
		if spent > 0:
			talents[String(tree_id)] = spent

	return {
		"time": Time.get_datetime_string_from_system(),
		"player": player,
		"level": _level_number(),
		"mode": MODE_NORMAL,
		"result": result,
		"wave": level.wave_runner.wave_number,
		"waves": level.wave_runner.wave_count,
		"life": level.player_stats.life,
		"start_life": start_life,
		"life_by_wave": life_by_wave,
		"start_gold": start_gold,
		"gold_earned": roundi(gold_earned),
		"gold_spent": roundi(gold_spent),
		"gold_left": roundi(level.player_stats.gold),
		"gold_by_wave": gold_by_wave,
		"spent_on": spent_on,
		"placed": placed,
		"buildings": buildings,
		"sold": sold,
		"destroyed": destroyed,
		"elements": elements,
		"upgrades": upgrades,
		"cards": cards,
		"early_starts": level.early_starts,
		"points": TalentRules.points_for_level(level) if is_won else 0,
		"talents": talents,
		"talent_points": PlayerProgress.get_talent_points_earned(),
		"killed": killed,
		"leaked": leaked,
		"game_seconds": roundi(game_seconds),
		"real_seconds": roundi((Time.get_ticks_msec() - start_msec) / 1000.0),
		"max_speed": max_time_scale,
		"cheats": used_cheats,
	}


func _level_number() -> int:
	if Utils.game_control == null or Utils.game_control.scene_manager == null:
		return 0
	return Utils.game_control.scene_manager.current_level_number


func _open_for_append() -> FileAccess:
	var file : FileAccess = null
	if FileAccess.file_exists(log_path):
		file = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(log_path, FileAccess.WRITE)

	if file == null:
		push_warning(name, OPEN_ERROR, FileAccess.get_open_error())
	return file


static func _building_type(building : Building) -> String:
	return building.scene_file_path.get_file().get_basename()
