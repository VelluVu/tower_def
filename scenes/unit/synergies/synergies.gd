class_name Synergies
extends Node

## The synergies (design doc "Synergies", the user's picks 2026-11-25, all sixteen), made by Level. Each is a small rule
## on a mechanic that already exists, called from where that mechanic lives; each shows itself with a SynergyFlash.
## - Traps: Pinned (an enemy the Leopard snapped takes double from spikes for SNAP_SECONDS), Shrapnel bed (an egg blast
##   beside a Spike Field fires it), Bait (a Leopard snap beside an egg lights its fuse), Trap line (a trap is
##   TRAP_LINE_BONUS stronger for each other trap kind beside it, at most TRAP_LINE_MOST).
## - Towers: Spotted shells (MortarShell aims at a marked enemy's real path), Pinned target (a tethered enemy takes a
##   blast's full hit), Hoard Guardian (an Elder Drake bites HOARD_GUARD_BONUS harder per Hoard Keeper near it), War cry
##   (a Buffer's roar readies an Elder Drake's breath, once a wave), Torn and marked (the Spotter's execute rises on
##   shredded enemies), Harmony (BufferAuras: a buffed tower of the Buffer's element gets twice its element chance).
## - Movement: Pushed onto spikes (a knocked-back enemy landing on a trap sets it off), Grounded on a trap (a harpooned
##   flyer lands on the nearest trap), Hold the line (Hatchery: guards rally on a trap cell), Cold feet (a Spike Field
##   strikes faster while chilled enemies stand on it).
## - Ground: Ground reactions (a burning patch meeting a poison cloud bursts, a chill patch on a burning one makes
##   steam: enemies in it cannot attack), Firebreath corridor (a Breather's gust through Fire walls sets everything in it
##   burning).

const SNAP_SECONDS : float = 1.5
const PINNED_FACTOR : float = 2.0
const TRAP_LINE_BONUS : float = 0.1
const TRAP_LINE_MOST : int = 2
const HOARD_GUARD_BONUS : float = 0.1
const HOARD_GUARD_MOST : int = 2
const HOARD_GUARD_TILES : float = 2.0
## Torn and marked: the execute threshold rises by this at three shred stacks (12% to 20%), in thirds per stack.
const TORN_EXECUTE : float = 0.08
const COLD_FEET_ATTACK_SPEED : float = 0.3
const GROUND_ON_TRAP_TILES : float = 2.0
## Ground reactions: the burst deals both patches' ticks times this, to every walking enemy within BURST_TILES.
const BURST_SHARE : float = 4.0
const BURST_TILES : float = 1.25
const STEAM_SECONDS : float = 2.0
## Flashes of the same synergy at the same spot come at most this often (game seconds).
const FLASH_GAP : float = 0.5
const SNAP_META : StringName = &"synergy_snapped_until"
const LEOPARD : StringName = &"leopard"
const SPIKES : StringName = &"spikes"
const EGG : StringName = &"egg"
const COLORS : Dictionary[StringName, Color] = {
	&"pinned": Color("feae34"), &"shrapnel": Color("f77622"), &"bait": Color("fee761"), &"trap_line": Color("c0cbdc"),
	&"spotted": Color("feae34"), &"pinned_target": Color("8b9bb4"), &"hoard": Color("feae34"), &"war_cry": Color("e43b44"),
	&"torn": Color("c0cbdc"), &"pushed": Color("ffffff"), &"grounded": Color("8b9bb4"), &"cold_feet": Color("2ce8f5"),
	&"burst": Color("f77622"), &"steam": Color("ffffff"), &"corridor": Color("e43b44"),
}

@onready var level : Level = get_parent()

var game_time : float = 0.0
var current_time_scale : float = 1.0
var is_refresh_queued : bool = false
#building instance id -> {"building": the building (untyped: may be freed), "mods": {key: ModifierData}}
var static_mods : Dictionary = {}
#the buildings going away this frame (sold or destroyed, still in the tree)
var leaving : Dictionary = {}
#elder drake instance id -> true once a roar readied its breath this wave
var war_cry_used : Dictionary = {}
#[enemy (untyped), the game time its steam ends]
var steamed : Array = []
#flash key -> the game time it last flashed
var last_flash : Dictionary = {}
#synergy kind -> how many times it fired this level (the bots' reports)
var counts : Dictionary[StringName, int] = {}


## The level's synergies, or null (a test without a level).
static func of_level(level_node : Node) -> Synergies:
	if level_node is Level:
		return (level_node as Level).synergies
	return null


static func trap_kind(building : Building) -> StringName:
	if building is EggBomb:
		return EGG
	if building is Trap:
		return SPIKES if building.skill is SpikeStrike else LEOPARD
	return &""


## Next to each other: one cell apart at most, diagonals too.
static func is_beside(a : Building, b : Building) -> bool:
	var gap : Vector2i = (a.grid_position - b.grid_position).abs()
	return a != b and maxi(gap.x, gap.y) <= 1


func _ready() -> void:
	GameSignals.building_placed.connect(_on_building_changed)
	GameSignals.sell_building.connect(_on_building_leaving)
	GameSignals.building_destroyed.connect(_on_building_leaving)
	GameSignals.enemy_hit.connect(_on_enemy_hit)
	GameSignals.wave_started.connect(func(_wave_number : int) -> void: war_cry_used.clear())
	GameSignals.time_scale_change.connect(func(time_scale : float) -> void: current_time_scale = time_scale)


func _process(delta : float) -> void:
	game_time += delta * current_time_scale
	for entry in steamed.duplicate():
		if entry[1] > game_time:
			continue
		steamed.erase(entry)
		if is_instance_valid(entry[0]):
			entry[0].remove_numb()


# --- static bonuses: Trap line, Hoard Guardian ---

func _on_building_changed(_building : Building) -> void:
	queue_refresh()


func _on_building_leaving(building : Building) -> void:
	leaving[building.get_instance_id()] = true
	_drop(building.get_instance_id())
	queue_refresh()


func queue_refresh() -> void:
	if is_refresh_queued:
		return
	is_refresh_queued = true
	refresh.call_deferred()


func refresh() -> void:
	is_refresh_queued = false
	var standing : Array[Building] = []
	for building in level.all_buildings:
		if is_instance_valid(building) and building.is_placed and not building.is_dead and not building.is_queued_for_deletion() \
				and not leaving.has(building.get_instance_id()):
			standing.append(building)
	leaving.clear()
	for building in standing:
		if building is Trap:
			_trap_line(building as Trap, standing)
		elif building is ElderDrake:
			_hoard_guard(building as ElderDrake, standing)


func _trap_line(trap : Trap, standing : Array[Building]) -> void:
	var kind : StringName = trap_kind(trap)
	var others : Dictionary = {}
	var partner : Building = null
	for other in standing:
		if other is Trap and is_beside(trap, other) and trap_kind(other) != kind:
			others[trap_kind(other)] = true
			partner = other
	var bonus : float = TRAP_LINE_BONUS * mini(others.size(), TRAP_LINE_MOST)
	if _set_bonus(trap, &"trap_line", bonus) and partner != null:
		flash(&"trap_line", trap.global_position, partner.global_position)


func _hoard_guard(elder : ElderDrake, standing : Array[Building]) -> void:
	var count : int = 0
	var keeper : Building = null
	for other in standing:
		if other is HoardKeeper and Vector2(other.grid_position - elder.grid_position).length() <= HOARD_GUARD_TILES:
			count += 1
			keeper = other
	if _set_bonus(elder, &"hoard", HOARD_GUARD_BONUS * mini(count, HOARD_GUARD_MOST)) and keeper != null:
		flash(&"hoard", elder.global_position, keeper.global_position)


## Puts a Multiply damage bonus on the building under key, swapping an old one; true when it grew.
func _set_bonus(building : Building, key : StringName, bonus : float) -> bool:
	var id : int = building.get_instance_id()
	if not static_mods.has(id):
		static_mods[id] = {"building": building, "mods": {}}
	var mods : Dictionary = static_mods[id]["mods"]
	var old : ModifierData = mods.get(key)
	var old_bonus : float = old.value if old != null else 0.0
	if is_equal_approx(old_bonus, bonus):
		return false
	if old != null:
		building.modifier_manager.remove_modifier(old)
		mods.erase(key)
	if bonus > 0.0:
		var data : ModifierData = ModifierData.new()
		data.modifier_type = Utils.ModifierType.StatModifier
		data.stat_type = Utils.StatType.Damage
		data.calculate_type = Utils.ModifyType.Multiply
		data.value = bonus
		building.modifier_manager.add_modifier(data)
		mods[key] = data
	building.stats_changed.emit()
	return bonus > old_bonus


func _drop(id : int) -> void:
	if not static_mods.has(id):
		return
	var entry : Dictionary = static_mods[id]
	static_mods.erase(id)
	var building = entry["building"]
	if not is_instance_valid(building):
		return
	for key in entry["mods"]:
		building.modifier_manager.remove_modifier(entry["mods"][key])


## The bonus of this key on the building now (tests, the selection card).
func get_bonus(building : Building, key : StringName) -> float:
	var entry : Dictionary = static_mods.get(building.get_instance_id(), {})
	var data : ModifierData = entry.get("mods", {}).get(key)
	return data.value if data != null else 0.0


# --- hits: Pinned, Bait ---

func _on_enemy_hit(enemy : Enemy, hit : DamageData) -> void:
	if hit.is_overtime or hit.is_reaction or hit.damage <= 0.0 or not is_instance_valid(hit.source) or not hit.source is Building:
		return
	var source : Building = hit.source
	if trap_kind(source) != LEOPARD:
		return
	enemy.set_meta(SNAP_META, game_time + SNAP_SECONDS)
	#Bait: the snap lights an egg beside the Leopard
	for building in level.all_buildings:
		if not is_instance_valid(building) or not building is EggBomb:
			continue
		var egg : EggBomb = building as EggBomb
		if egg.is_placed and is_beside(source, egg) and not egg.is_rebuilding and egg.skill.is_ready and not enemy.is_dead:
			egg.skill.use(enemy)
			flash(&"bait", source.global_position, egg.global_position)


## The extra factor on a hit (Enemy.take_damage): Pinned doubles the spikes on an enemy the Leopard holds.
func get_damage_factor(enemy : Enemy, hit : DamageData) -> float:
	if hit.is_overtime or not is_instance_valid(hit.source) or not hit.source is Building:
		return 1.0
	if trap_kind(hit.source) == SPIKES and float(enemy.get_meta(SNAP_META, -1.0)) > game_time:
		flash(&"pinned", hit.source.global_position, enemy.global_position)
		return PINNED_FACTOR
	return 1.0


# --- traps set off by other things: Shrapnel bed, Pushed onto spikes, Grounded on a trap ---

## Makes a trap fire now: it re-arms at once and strikes whatever stands on it. An egg still rebuilding or a trap
## already striking stays as it is; false then.
static func ready_trap(trap : Trap) -> bool:
	if not is_instance_valid(trap) or trap.is_dead or not trap.is_placed:
		return false
	if trap is EggBomb and trap.is_rebuilding:
		return false
	if trap.skill.is_ready:
		#the first one still standing there: a freed one in the typed parameter is a script error
		for target in trap.targets:
			if is_instance_valid(target):
				trap.skill.use(target)
				break
		return true
	if not trap.skill.cast_timer.is_stopped():
		return false
	trap.skill.cooldown_timer.stop()
	trap.skill._on_cooldown_end()
	return true


## Shrapnel bed: an egg's blast fires every Spike Field beside it.
func on_egg_blast(egg : EggBomb) -> void:
	for building in level.all_buildings:
		if is_instance_valid(building) and building is Trap and trap_kind(building) == SPIKES and is_beside(egg, building):
			if ready_trap(building as Trap):
				flash(&"shrapnel", egg.global_position, building.global_position)


## Pushed onto spikes: an enemy knocked back onto a trap sets it off at once.
func on_knocked_back(enemy : Enemy) -> void:
	if enemy.ignores_traps or enemy.is_dead:
		return
	var building : Building = level.grid.get_building_from_cell_position(enemy.grid_position)
	if building is Trap and ready_trap(building as Trap):
		flash(&"pushed", enemy.global_position)


## Grounded on a trap: a flyer a harpoon pulls down lands on the nearest trap within GROUND_ON_TRAP_TILES.
func on_grounded(enemy : Enemy) -> void:
	if enemy.ignores_traps or enemy.is_dead or enemy.end_point == null:
		return
	var best : Trap = null
	var best_distance : float = GROUND_ON_TRAP_TILES * Utils.TILE_SIZE
	for building in level.all_buildings:
		if not is_instance_valid(building) or not building is Trap or not building.is_placed or building.is_dead:
			continue
		var distance : float = building.global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = building as Trap
			best_distance = distance
	if best == null:
		return
	enemy.global_position = best.global_position
	enemy.path_to(enemy.global_position, enemy.end_point.global_position)
	ready_trap(best)
	flash(&"grounded", best.global_position)


## Cold feet: a Spike Field strikes faster while chilled enemies stand on it (SpikeStrike after each strike).
func update_cold_feet(spikes : Trap, has_chilled : bool) -> void:
	var was_on : bool = get_bonus(spikes, &"cold_feet") > 0.0
	if has_chilled == was_on:
		return
	var id : int = spikes.get_instance_id()
	if not static_mods.has(id):
		static_mods[id] = {"building": spikes, "mods": {}}
	var mods : Dictionary = static_mods[id]["mods"]
	if has_chilled:
		var data : ModifierData = ModifierData.new()
		data.modifier_type = Utils.ModifierType.StatModifier
		data.stat_type = Utils.StatType.AttackSpeed
		data.calculate_type = Utils.ModifyType.Flat
		data.value = COLD_FEET_ATTACK_SPEED
		spikes.modifier_manager.add_modifier(data)
		mods[&"cold_feet"] = data
		flash(&"cold_feet", spikes.global_position)
	else:
		spikes.modifier_manager.remove_modifier(mods[&"cold_feet"])
		mods.erase(&"cold_feet")


## Chilled for Cold feet: frozen, carrying Frost stacks, or beside a Frost wall.
func is_chilled(enemy : Enemy) -> bool:
	if TalentEffect.enemy_in(enemy, TalentEffect.Condition.Chilled):
		return true
	for wall in level.grid.get_maze_walls(enemy.grid_position):
		if wall.element == Utils.Element.Frost:
			return true
	return false


# --- towers: Spotted shells, Pinned target, War cry, Torn and marked ---

## Spotted shells: where a marked enemy will be after seconds, walking its own path (no lead cap).
static func predict_on_path(enemy : Enemy, seconds : float) -> Vector2:
	var time_scale : float = maxf(Utils.game_control.time_scale, 0.01) if Utils.game_control != null else 1.0
	var left : float = enemy.linear_velocity.length() / time_scale * seconds
	var at : Vector2 = enemy.global_position
	var index : int = enemy.current_waypoint_index
	while left > 0.0 and index < enemy.point_path.size():
		var next : Vector2 = enemy.point_path[index] + enemy.lane_offset
		var step : float = at.distance_to(next)
		if step >= left:
			return at.move_toward(next, left)
		left -= step
		at = next
		index += 1
	return at


static func is_spotted(enemy : Enemy) -> bool:
	return enemy.get_node_or_null(NodePath(EnemyMarks.NODE_NAME)) != null


## Pinned target: a tethered enemy takes a blast's full hit wherever it stands in it.
func get_blast_share(enemy : Enemy, share : float) -> float:
	var tether : HarpoonTether = enemy.get_node_or_null(NodePath(HarpoonTether.NODE_NAME)) as HarpoonTether
	if tether != null and tether.is_tethered() and share < 1.0:
		flash(&"pinned_target", enemy.global_position)
		return 1.0
	return share


## War cry: a Buffer's roar readies the breath of every Elder Drake in its aura, once a wave each.
func on_roar(buffer : Buffer) -> void:
	for building in level.all_buildings:
		if not is_instance_valid(building) or not building is ElderDrake or not building.is_placed or building.is_dead:
			continue
		var elder : ElderDrake = building as ElderDrake
		if elder.is_breath_ready or war_cry_used.has(elder.get_instance_id()) or not buffer.covers(elder.global_position):
			continue
		elder.is_breath_ready = true
		war_cry_used[elder.get_instance_id()] = true
		flash(&"war_cry", buffer.global_position, elder.global_position)


## Torn and marked: how much higher the Spotter's execute reaches on this shredded enemy.
static func get_execute_bonus(enemy : Enemy) -> float:
	var shred : ResistanceShred = enemy.get_node_or_null(NodePath(ResistanceShred.NAME)) as ResistanceShred
	if shred == null or shred.stacks <= 0:
		return 0.0
	return TORN_EXECUTE * float(mini(shred.stacks, Shredder.MAX_STACKS)) / Shredder.MAX_STACKS


# --- ground: Ground reactions, Firebreath corridor ---

## Ground reactions: a new patch meeting another of a partner element.
func on_patch(patch : GroundPatch) -> void:
	var reach : float = GroundPatch.RADIUS_TILES * Utils.TILE_SIZE * 2.0
	for node in get_tree().get_nodes_in_group(GroupNames.GROUND_PATCHES):
		var other : GroundPatch = node as GroundPatch
		if other == null or other == patch or other.is_queued_for_deletion() or other.ticks_left <= 0:
			continue
		if other.global_position.distance_to(patch.global_position) > reach:
			continue
		var pair : Array = [patch.damage_type, other.damage_type]
		if pair.has(Utils.DamageType.Fire) and pair.has(Utils.DamageType.Poison):
			_burst(patch, other)
			return
		if pair.has(Utils.DamageType.Fire) and pair.has(Utils.DamageType.Frost):
			_steam(patch, other)
			return


func _burst(patch : GroundPatch, other : GroundPatch) -> void:
	var at : Vector2 = (patch.global_position + other.global_position) * 0.5
	var damage : float = (patch.tick_damage + other.tick_damage) * BURST_SHARE
	var source : Building = patch.tower if is_instance_valid(patch.tower) else null
	patch.queue_free()
	other.queue_free()
	flash(&"burst", at)
	for enemy in level.existing_enemies.duplicate():
		if not EnemyQuery.is_hittable(enemy) or enemy.is_flying or enemy.global_position.distance_to(at) > BURST_TILES * Utils.TILE_SIZE:
			continue
		var hit : DamageData = DamageData.new()
		hit.is_reaction = true
		hit.damage_type = Utils.DamageType.Fire
		hit.damage = damage
		hit.source = source
		enemy.take_damage(hit)
		hit.free()


func _steam(patch : GroundPatch, other : GroundPatch) -> void:
	var fire : GroundPatch = patch if patch.damage_type == Utils.DamageType.Fire else other
	var at : Vector2 = fire.global_position
	fire.queue_free()
	flash(&"steam", at)
	for enemy in level.existing_enemies:
		if not EnemyQuery.is_hittable(enemy) or enemy.is_flying or enemy.global_position.distance_to(at) > BURST_TILES * Utils.TILE_SIZE:
			continue
		enemy.add_numb()
		steamed.append([enemy, game_time + STEAM_SECONDS])


## Firebreath corridor: true when a Fire wall stands in the Breather's cone.
func is_fire_corridor(breath : Breath) -> bool:
	for building in level.all_buildings:
		if is_instance_valid(building) and building is Wall and building.is_placed and (building as Wall).element == Utils.Element.Fire \
				and breath.is_point_in_cone(building.global_position):
			return true
	return false


## Firebreath corridor: the gust sets an enemy burning (one stack of the Fire burn, the Breather's effect stats).
func corridor_burn(enemy : Enemy, breather : Building, raw_damage : float) -> void:
	if enemy.is_dead:
		return
	var burn : DamageData = BufferAuras.PASS_ON_DATA[Utils.Element.Fire].instantiate()
	burn.source = breather
	for effect_data in burn.overtime_effect_datas:
		effect_data.chance_to_apply = 1.0
		effect_data.read_source_stats(breather.stats)
	enemy.overtime_effect_handler.handle_overtime_effects(burn.overtime_effect_datas, raw_damage)
	burn.free()
	flash(&"corridor", breather.global_position, enemy.global_position)


# --- the flash ---

## Shows a synergy: a line from a to b, or a ring at a; the same synergy at the same spot at most every FLASH_GAP.
func flash(kind : StringName, a : Vector2, b : Vector2 = Vector2.INF) -> void:
	counts[kind] = counts.get(kind, 0) + 1
	var key : String = "%s:%d:%d" % [kind, roundi(a.x / Utils.TILE_SIZE), roundi(a.y / Utils.TILE_SIZE)]
	if float(last_flash.get(key, -INF)) + FLASH_GAP > game_time:
		return
	last_flash[key] = game_time
	var color : Color = COLORS.get(kind, Color.WHITE)
	if b == Vector2.INF:
		SynergyFlash.ring(level, a, color)
	else:
		SynergyFlash.line(level, a, b, color)
