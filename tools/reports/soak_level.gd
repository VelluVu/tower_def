extends RefCounted

## A bot plays one level through the real Main and reports the result, lives, reactions and damage
## per tower and enemy type; the run is also written to user://bot_playtests.jsonl like a player's
## run (`python tools/playtests.py --bot`). Script errors show up in the output.
## `python tools/gd.py run tools/reports/soak_level.gd level=4 [key=value...] --raw`
##   economy=real|free   real: the level's own gold; free: gold is topped up every frame
##   build=mixed|fire|frost|poison|physical  a tactic (BUILDS): its tower types, their element, its tree and
##                       the stats its cards should raise; mixed = every tower type, elements by rotation
##   talents=none|all|fire:30,building:10|focus:30|budget:120   points per tree (focus = the build's tree; budget = a
##                       player's total: the build's tree first, then Building, then the other trees), spent on the
##                       nearest working nodes, nodes that fit the build first
##   cards=random|fit    random offer, or the offer that best fits the build (its stats, then the luckiest roll)
##   mode=normal|hard|survival  the level mode (hard: the level's LevelModeData scales the waves and enemies;
##                       survival: endless waves, the result is the wave the lives ran out in)
##   health=1.0 speed=1.0 life=N             extra enemy multipliers and starting life, on top of the mode
##   rotation=0-2        which element each tower type takes (Fire, Frost, Poison shifted by rotation)
##   order=fixed|shuffle tower types in Bolter, Nova, Beamer order or shuffled
##   towers=40 traps=5   most towers and traps the bot builds (12 left hundreds of gold unspent late; 2 traps left
##                       the maze traps untested, 2026-11-26)
##   trap=mixed|leopard_trap|egg_bomb|spike_field  which traps: mixed takes turns between the unlocked ones
##   wall_min_towers=5   no walls before this many towers (a player builds a defence before a maze)
##   min_towers=3        towers placed before anything else
##   depth=3             purchases every tower gets before the next tower (3 = Up 1, Up 2, element)
##   walls=0.3           share of the spent gold that may go to walls (maze), 0 = no walls
##   early=0|1           start waves early, or only once a wave is cleared
##   unlocked=level|all  level: only the buildings unlocked by this level (BuildingListElement.unlock_level)
##   seed=1 speed_up=3.0
##   chaos=N            every N game seconds of a wave, sell a random building (freed-mid-fight bugs); 0 = off
##   types=puffe_bolter,puffe_nova  only these tower types (over the build's), still only unlocked ones
##   play=rules|smart   rules: the fixed rules above; smart: smart_play.gd values every action by the damage it
##                       adds per gold and buys the best (ignores depth, min_towers, the wall share and
##                       wall_min_towers; walls=0 still turns walls off), picks cards by their gain, starts early when safe
##   smart=smart_play    the smart player's script in tools/reports/ (smart_play_v2: pair walls, a knapsack per
##                       build break, sells towers the route has left)

const MAIN_SCENE : String = "res://scenes/main.tscn"
const TOWERS : Array[String] = ["puffe_bolter", "puffe_nova", "puffe_beamer", "puffe_mortar", "puffe_buffer", "puffe_breather", "puffe_spotter", "puffe_harpooner", "puffe_hatchery", "puffe_shredder", "puffe_elder", "puffe_hoard"]
const BUFFER : String = "puffe_buffer"
## A Buffer goes down once this many other towers stand, where it reaches the most of them.
const BUFFER_MIN_TOWERS : int = 3
const TRAP : String = "leopard_trap"
const EGG_BOMB : String = "egg_bomb"
const SPIKE_FIELD : String = "spike_field"
## The Hoard Keeper covers nothing: it goes on a free cell off the routes.
const HOARD : String = "puffe_hoard"
const HOARD_MIN_TOWERS : int = 4
## A build's first CORE_TYPES tower types are its core; each later type (the newer towers, Buffer, Hoard) may stand
## at most once per EXTRA_PER_CORE core towers. Without it the bot spread over seven types on late levels and lost
## 48 and 60, which it won flawlessly with the core three (2026-11-26).
const CORE_TYPES : int = 3
const EXTRA_PER_CORE : int = 2
## Towers that deal no damage count their purchases this many times when the bot picks the least upgraded tower,
## so they get a share of the upgrades, not an equal one (19-35 Hoard Keeper steps on level 12, 2026-11-26).
const SUPPORT_UPGRADE_WEIGHT : int = 2
const WALL : String = "wall"
## Element walls (_buy_wall_step): from this many walls, tried on this share of the spending turns.
const WALL_ELEMENT_MIN_WALLS : int = 4
const WALL_ELEMENT_CHANCE : float = 0.15
const BUILDING_LIST_PATH : String = "res://scenes/unit/building/buildings/%s.tres"
const LEAVES : Array[String] = ["FireElementEvolveLeaf", "FrostElementEvolveLeaf", "PoisonElementEvolveLeaf"]
const TALENT_BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")
const LEVEL_SECONDS : float = 1500.0
const LEVEL_LOAD_FRAMES : int = 600
const FREE_GOLD : float = 9999.0
const BLOCKED_WEIGHT : float = 100.0
const DIGITS : String = "0123456789"
const LEAF_META : StringName = &"soak_leaf"
const RANGE_META : StringName = &"soak_range"
const WALL_COVER_WEIGHT : int = 1000
## Synergy habits (design doc Synergies): a partner nearby is worth this many route cells to a tower's cell (at
## most two partners), a trap of another kind beside a trap cell this many towers reaching it.
const SYNERGY_CELLS : float = 3.0
## The towers' niches (TowerNiches): route cells worth more to the tower kind that shines there.
const NICHES = preload("res://tools/reports/bot_niches.gd")
const TRAP_PAIR_SCORE : int = 2
const TOWER_FLAGS : Dictionary[String, int] = {"puffe_bolter": TalentEffect.BOLTER, "puffe_nova": TalentEffect.NOVA, "puffe_beamer": TalentEffect.BEAMER,
	"puffe_mortar": TalentEffect.MORTAR, "puffe_buffer": TalentEffect.BUFFER, "puffe_breather": TalentEffect.BREATHER, "puffe_spotter": TalentEffect.SPOTTER, "puffe_harpooner": TalentEffect.HARPOONER, "puffe_hatchery": TalentEffect.HATCHERY, "egg_bomb": TalentEffect.EGG_BOMB,
	"spike_field": TalentEffect.SPIKE_FIELD, "puffe_shredder": TalentEffect.SHREDDER, "puffe_elder": TalentEffect.ELDER_DRAKE, "puffe_hoard": TalentEffect.HOARD_KEEPER}
## A build: the tower types in build order (the towers since 2026-11-24 after the first three, so the opening is the
## same as before), their element leaf, its talent tree, its wall share and the card
## stats it wants most first. A tower type not unlocked yet is skipped (the Bolter always is).
const BUILDS : Dictionary[String, Dictionary] = {
	"mixed": {},
	"fire": {"towers": ["puffe_bolter", "puffe_nova", "puffe_breather", "puffe_mortar", "puffe_elder", "puffe_buffer", "puffe_hoard"], "leaf": "FireElementEvolveLeaf", "element": Utils.Element.Fire, "tree": "fire", "walls": 0.3,
		"cards": [Utils.StatType.Damage, Utils.StatType.AttackSpeed, Utils.StatType.EffectPotency, Utils.StatType.CriticalChance]},
	#opens with a Beamer: a Nova first lost wave 1 often and never hits flyers (2026-11-20)
	"frost": {"towers": ["puffe_beamer", "puffe_nova", "puffe_bolter", "puffe_harpooner", "puffe_hatchery", "puffe_shredder", "puffe_buffer", "puffe_hoard"], "leaf": "FrostElementEvolveLeaf", "element": Utils.Element.Frost, "tree": "frost", "walls": 0.5,
		"cards": [Utils.StatType.EffectPotency, Utils.StatType.AttackRange, Utils.StatType.Damage, Utils.StatType.AttackSpeed]},
	"poison": {"towers": ["puffe_beamer", "puffe_bolter", "puffe_mortar", "puffe_breather", "puffe_spotter", "puffe_buffer", "puffe_hoard"], "leaf": "PoisonElementEvolveLeaf", "element": Utils.Element.Poison, "tree": "poison", "walls": 0.3,
		"cards": [Utils.StatType.EffectPotency, Utils.StatType.Damage, Utils.StatType.ActiveDuration, Utils.StatType.AttackSpeed]},
	#a cheese check: Bolters only, no maze (the user won Normal levels with three upgraded Bolters)
	"bolter": {"towers": ["puffe_bolter"], "leaf": "PhysicalElementEvolveLeaf", "element": Utils.Element.Physical, "tree": "building", "walls": 0.0,
		"cards": [Utils.StatType.Damage, Utils.StatType.AttackSpeed, Utils.StatType.CriticalChance, Utils.StatType.CriticalMultiplier]},
	"physical": {"towers": ["puffe_bolter", "puffe_beamer", "puffe_nova", "puffe_spotter", "puffe_shredder", "puffe_elder", "puffe_buffer", "puffe_hoard"], "leaf": "PhysicalElementEvolveLeaf", "element": Utils.Element.Physical, "tree": "building", "walls": 0.4,
		"cards": [Utils.StatType.Damage, Utils.StatType.CriticalChance, Utils.StatType.CriticalMultiplier, Utils.StatType.AttackSpeed]},
}

var options : Dictionary[String, String] = {
	"level": "1", "mode": "normal", "build": "mixed", "cards": "random", "economy": "real", "talents": "none", "health": "1.0", "speed": "1.0", "life": "",
	"rotation": "0", "order": "fixed", "towers": "40", "traps": "5", "min_towers": "3", "depth": "3", "wall_min_towers": "5",
	"walls": "0.3", "early": "0", "unlocked": "level", "seed": "1", "speed_up": "3.0", "play": "rules", "types": "",
	"smart": "smart_play", "chaos": "0", "trap": "mixed",
}
#chaos=N: every N game seconds of a wave a random building is sold, so shots, beams and effects lose their tower mid-fight
var chaos_interval : float = 0.0
var chaos_left : float = 0.0
var chaos_sold : int = 0
const SMART_PATH : String = "res://tools/reports/%s.gd"
var smart : RefCounted = null
var towers : Array[Building] = []
var traps : int = 0
var walls : int = 0
var purchases : Dictionary[Building, int] = {}
var prices : Dictionary[String, float] = {}
var type_order : Array[int] = []
var gold_spent : float = 0.0
var wall_gold : float = 0.0
#the paths only change when a building goes up, so the costly searches are cached until then
var cached_paths : Array[PackedVector2Array] = []
var cached_ids : Dictionary[int, bool] = {}
var is_wall_exhausted : bool = false

var reactions : Dictionary[String, int] = {}
var tower_damage : Dictionary[String, float] = {}
#direct hits per wave (the damage numbers a player sees): [count, sum, biggest]
var wave_hits : Dictionary[int, Array] = {}
var current_wave : int = 0
var enemy_damage : Dictionary[String, float] = {}
var spawned : Dictionary[String, int] = {}
var killed : Dictionary[String, int] = {}
var leaked : Dictionary[String, int] = {}
var cards : int = 0
var result : String = "timeout"
var build : Dictionary = {}


func run(kit : TestKit, args : PackedStringArray) -> void:
	var given : Dictionary[String, bool] = {}
	for arg in args:
		var parts : PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
			given[parts[0]] = true
	build = BUILDS.get(options.build, {})
	#the build's wall share, unless walls= was given
	if build.has("walls") and not given.has("walls"):
		options.walls = str(build.walls)
	seed(int(options.seed))
	PlaytestLog.is_enabled = true
	PlaytestLog.player = "bot " + " ".join(args)

	var spent_talents : Dictionary[String, int] = _spend_talents(options.talents)
	if options.play == "smart":
		smart = (load(SMART_PATH % options.smart) as GDScript).new(self)
	var main : Main = load(MAIN_SCENE).instantiate()
	kit.root.add_child(main)
	await kit.frames(2)

	var modes : Dictionary = {"normal": Utils.LevelMode.Normal, "hard": Utils.LevelMode.Hard, "survival": Utils.LevelMode.Survival}
	UISignals.start_level_button_pressed.emit(int(options.level), modes.get(options.mode, Utils.LevelMode.Normal))
	var level : Level = null
	for i in LEVEL_LOAD_FRAMES:
		await kit.frames()
		level = main.scene_manager.current_level as Level
		if level != null and level.is_node_ready():
			break
	kit.level = level
	await kit.frames(2)

	if not options.life.is_empty():
		level.player_stats.life = float(options.life)
	var starting_life : float = level.player_stats.life
	var is_free : bool = options.economy == "free"

	GameSignals.element_reaction.connect(func(_p : Vector2, reaction : ElementReaction) -> void: _add(reactions, reaction.display_name, 1))
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.enemy_hit.connect(_on_enemy_hit)
	GameSignals.wave_started.connect(func(wave : int) -> void: current_wave = wave)
	GameSignals.enemy_destroyed.connect(func(enemy : Enemy) -> void: _add(killed, _type_of(enemy), 1))
	GameSignals.enemy_reached_end_point.connect(func(enemy : Enemy) -> void: _add(leaked, _type_of(enemy), 1))
	GameSignals.level_completed.connect(func(_l : Level) -> void: result = "won")
	GameSignals.lose_game.connect(func() -> void: result = "lost")
	GameSignals.astar_grid_updated.connect(func() -> void:
		cached_paths.clear()
		is_wall_exhausted = false)

	print("SOAK level %s %s, build %s, cards %s, %s economy, start gold %.0f, talents %s, health x%s, speed x%s, life %.0f" % [
		options.level, options.mode, options.build, options.cards, options.economy, level.player_stats.gold, spent_talents, options.health, options.speed, starting_life])

	var speed_up : float = float(options.speed_up)
	main.time_scale = speed_up
	GameSignals.time_scale_change.emit(speed_up)
	var is_early : bool = options.early == "1"
	var start_length : int = _route_length(level)

	chaos_interval = float(options.chaos)
	chaos_left = chaos_interval
	var time : float = 0.0
	while result == "timeout" and time < LEVEL_SECONDS:
		if is_free:
			level.player_stats.gold = FREE_GOLD
		#Survival never ends on its own: past the last points milestone counts as a win
		if level.wave_runner.is_endless and level.wave_runner.wave_number > SurvivalRules.MILESTONES[-1]:
			result = "won"
			break
		#the first wave waits until the opening build is done
		if smart != null:
			await smart.step(kit, level)
		else:
			await _spend(kit, level)
		if not level.upgrades.offered_cards.is_empty():
			cards += 1
			var card : int = smart.pick_card(level, level.upgrades.offered_cards) if smart != null else _pick_card(level.upgrades.offered_cards)
			level.upgrades._on_upgrade_card_selected(card)
		#or the opening is as built as the gold allows (a player starts the wave rather than wait for gold that never comes)
		var is_ready : bool = level.wave_runner.wave_number > 0 or towers.size() >= int(options.min_towers) \
			or (not towers.is_empty() and not _tower_types().any(func(type : String) -> bool: return _is_wanted_now(type) and level.player_stats.has_enough_gold(_placement_price(level, type))))
		var wants_early : bool = is_early
		if smart != null:
			is_ready = level.wave_runner.wave_number > 0 or (smart.is_idle and not towers.is_empty())
			wants_early = smart.wants_early(level)
		if is_ready and level.wave_runner.can_start_next_wave and (wants_early or level.existing_enemies.is_empty()):
			UISignals.start_wave_pressed.emit()
		await kit.root.get_tree().process_frame
		var frame_time : float = kit.root.get_process_delta_time()
		time += frame_time
		if smart != null:
			smart.tick(level, frame_time * main.time_scale)
		if chaos_interval > 0.0 and not level.existing_enemies.is_empty():
			chaos_left -= frame_time * main.time_scale
			if chaos_left <= 0.0:
				chaos_left = chaos_interval
				_chaos_sell(level)

	if result == "timeout":
		#a wave that never ends: who is still alive, and where
		for enemy in level.existing_enemies:
			if is_instance_valid(enemy):
				print("SOAK stuck %s at cell %s, health %.0f, burrowed %s" % [enemy.name, level.grid.world_position_to_grid(enemy.global_position),
					enemy.stats.get_stat_value(Utils.StatType.Health), enemy.is_burrowed])
				print("SOAK stuck   waypoint %d/%d next %s, velocity %s, deactivated %s, frozen %s, colliding building %s, path %s" % [
					enemy.current_waypoint_index, enemy.point_path.size(), level.grid.world_position_to_grid(enemy.next_waypoint),
					enemy.velocity, enemy.is_deactivated, enemy.is_frozen, enemy.is_colliding_building,
					Array(enemy.point_path).map(func(p : Vector2) -> Vector2i: return level.grid.world_position_to_grid(p))])
	await kit.frames(2)
	var elements : Dictionary[String, String] = {}
	var bought : Dictionary[String, int] = {}
	for tower in towers:
		if is_instance_valid(tower):
			#a tower that has not chosen yet reads as Physical
			if tower.evolve_tree.is_element_chosen:
				elements[_type_of(tower)] = Utils.Element.find_key(tower.evolve_tree.evolve_element)
			_add(bought, _type_of(tower), purchases.get(tower, 0))
	#Survival has no last wave (wave_count 0)
	var wave_text : String = str(level.wave_runner.wave_number) if level.wave_runner.wave_count == 0 \
		else "%d/%d" % [level.wave_runner.wave_number, level.wave_runner.wave_count]
	print("SOAK result %s: wave %s, life %.0f/%.0f, cards %d, early starts %d, gold left %.0f" % [
		result, wave_text, level.player_stats.life, starting_life, cards, level.early_starts, level.player_stats.gold])
	print("SOAK built %d towers, %d traps, %d walls (%.0f of %.0f gold), route %d -> %d cells, purchases %s, elements %s" % [
		towers.size(), traps, walls, wall_gold, gold_spent, start_length, _route_length(level), bought, elements])
	if smart != null:
		print("SOAK smart bought %s" % smart.bought)
		#each kind's real damage over its stats' promise: SHEET_BASE_DPS against walking enemies
		print("SOAK smart learned %s" % smart.learned_report())
	print("SOAK enemies spawned %s, killed %s, leaked %s" % [spawned, killed, leaked])
	print("SOAK damage by tower %s" % _rounded(tower_damage))
	print("SOAK damage by enemy %s" % _rounded(enemy_damage))
	var hit_texts : PackedStringArray = []
	for wave in wave_hits:
		var hits : Array = wave_hits[wave]
		hit_texts.append("w%d avg %.2f max %.2f" % [wave, hits[1] / maxf(hits[0], 1.0), hits[2]])
	print("SOAK direct hits %s" % ", ".join(hit_texts))
	print("SOAK reactions %s" % reactions)
	print("SOAK synergies %s" % (level.synergies.counts if level.synergies != null else {}))
	if chaos_interval > 0.0:
		print("SOAK chaos sold %d buildings mid-wave" % chaos_sold)
	main.get_tree().paused = false
	#writes this run to the bot log
	level.queue_free()
	await kit.frames(2)
	#the smart player holds this bot and the bot holds it: break the RefCounted cycle, or both leak at exit
	smart = null


## Spends each tree's points one rank at a time on the nearest node that can take it, working
## nodes first, so the points buy what a player would. "all" maxes every node.
func _spend_talents(spec : String) -> Dictionary[String, int]:
	var budgets : Dictionary[String, int] = {}
	#budget:N: one total, spent like a player who has learned a lot: the build's own tree, then Building, then the rest
	var total_budget : int = int(spec.get_slice(":", 1)) if spec.begins_with("budget:") else -1
	for part in ([] if total_budget >= 0 else spec.split(",", false)):
		var pair : PackedStringArray = part.split(":")
		if pair.size() == 2:
			var tree_id : String = build.get("tree", "building") if pair[0] == "focus" else pair[0]
			budgets[tree_id] = budgets.get(tree_id, 0) + int(pair[1])

	var spent : Dictionary[String, int] = {}
	var trees : Array[TalentTree] = TALENT_BOOK.trees.duplicate()
	if total_budget >= 0:
		var first : String = build.get("tree", "building")
		trees.sort_custom(func(a : TalentTree, b : TalentTree) -> bool:
			var rank_a : int = 0 if String(a.id) == first else 1 if a.id == &"building" else 2
			var rank_b : int = 0 if String(b.id) == first else 1 if b.id == &"building" else 2
			return rank_a < rank_b)
	for tree in trees:
		PlayerProgress.reset_talent_tree(tree.id)
		var ranks : Dictionary = {}

		if spec == "all":
			for node in tree.nodes:
				ranks[node.id] = node.max_rank
		else:
			var points : int = budgets.get(String(tree.id), 0) if total_budget < 0 else total_budget
			var steps : Dictionary[StringName, int] = _tree_steps(tree)
			while points > 0:
				var best : TalentNode = null
				for node in tree.nodes:
					if TalentRules.can_add(tree, ranks, node, points) and (best == null or _is_better_node(node, best, steps)):
						best = node
				if best == null or (total_budget >= 0 and not best.is_implemented):
					break
				ranks[best.id] = TalentRules.get_rank(ranks, best.id) + 1
				points -= 1
			#the budget's rest goes on to the next tree, working nodes only (a player skips the idle ones)
			if total_budget >= 0:
				total_budget = points

		for node_id in ranks:
			PlayerProgress.set_talent_rank(tree.id, node_id, ranks[node_id])
		if not ranks.is_empty():
			spent[String(tree.id)] = TalentRules.get_spent(ranks)
			print("SOAK talent nodes %s %s" % [tree.id, ranks])

	return spent


func _is_better_node(node : TalentNode, other : TalentNode, steps : Dictionary[StringName, int]) -> bool:
	if node.is_implemented != other.is_implemented:
		return node.is_implemented
	var fits : bool = _node_fits_build(node)
	if fits != _node_fits_build(other):
		return fits
	return steps.get(node.id, 99) < steps.get(other.id, 99)


## A node helps the build when one of its effects is start gold or reaches the build's towers in its element.
func _node_fits_build(node : TalentNode) -> bool:
	if build.is_empty():
		return true
	var tower_flags : int = 0
	for scene_name in build.towers:
		tower_flags |= TOWER_FLAGS[scene_name]
	for effect in node.effects:
		if effect.kind == TalentEffect.Kind.StartGold:
			return true
		if effect.buildings & tower_flags != 0 and (effect.elements == 0 or effect.elements & int(build.element) != 0):
			return true
	return false


## The offer to take: random, or with cards=fit the one whose stat the build wants most, then the
## luckiest roll (a rolled x3 beats a plain x1 of the same stat).
func _pick_card(offered : Array[UpgradeCard]) -> int:
	if options.cards != "fit" or build.is_empty():
		return randi() % offered.size()
	var best : int = 0
	var best_score : float = -INF
	var wanted : Array = build.cards
	for index in offered.size():
		var card : UpgradeCard = offered[index]
		var rank : int = wanted.find(card.resource.modify_stat_type)
		var is_stat : bool = card.resource.card_target == EvolveResource.CardTarget.Buildings
		var score : float = float(wanted.size() - rank) * 2.0 if rank >= 0 and is_stat else 0.0
		if card.resource.elements != 0 and card.resource.elements & int(build.element) == 0:
			score -= 4.0
		if card.resource.modify_value != 0.0:
			score += card.value / card.resource.modify_value
		if score > best_score:
			best_score = score
			best = index
	return best


## The tower types this run builds, in order: the build's unlocked ones, or every unlocked type.
func _tower_types() -> Array[String]:
	var types : Array[String] = []
	var wanted : Array = build.get("towers", TOWERS) if options.types.is_empty() else Array(options.types.split(",", false))
	for scene_name in wanted:
		if _is_unlocked(scene_name):
			types.append(scene_name)
	if types.is_empty():
		types.append(TOWERS[0])
	return types


func _tree_steps(tree : TalentTree) -> Dictionary[StringName, int]:
	var opens : Dictionary[StringName, Array] = TalentRules.get_opens(tree)
	var steps : Dictionary[StringName, int] = {tree.start_id: 0}
	var queue : Array[StringName] = [tree.start_id]
	while not queue.is_empty():
		var current : StringName = queue.pop_front()
		for next_id in opens.get(current, []):
			if not steps.has(next_id):
				steps[next_id] = steps[current] + 1
				queue.append(next_id)
	return steps


## chaos=N: sells a random standing building mid-wave, as a player changing their mind would; the bot rebuilds.
func _chaos_sell(level : Level) -> void:
	var standing : Array[Building] = []
	for candidate in level.all_buildings:
		if is_instance_valid(candidate) and candidate.is_placed and not candidate.is_dead:
			standing.append(candidate)
	if standing.is_empty():
		return
	var sold : Building = standing.pick_random()
	towers.erase(sold)
	purchases.erase(sold)
	chaos_sold += 1
	GameSignals.sell_building.emit(sold)


## One action a frame, like a player clicking: the first towers, then walls while they are under
## their share of the gold, then upgrades up to depth, then the next tower or trap.
## Waits (saves gold) when the chosen action costs more than it has.
func _spend(kit : TestKit, level : Level) -> void:
	var tower_cap : int = int(options.towers)
	if towers.size() < int(options.min_towers):
		await _place_tower(kit, level)
		return

	var wall_share : float = float(options.walls)
	if wall_share > 0.0 and not is_wall_exhausted and wall_gold <= wall_share * gold_spent and towers.size() >= int(options.wall_min_towers):
		if level.player_stats.has_enough_gold(_price_of(WALL)):
			var wall_cell : Vector2i = _best_wall_cell(level)
			if wall_cell != Vector2i.MAX:
				await _place(kit, level, WALL, wall_cell)
				walls += 1
				return
			is_wall_exhausted = true
		else:
			return

	var behind : Building = null
	for tower in towers:
		if is_instance_valid(tower) and _has_options(level, tower) and (behind == null or _upgrade_rank(tower) < _upgrade_rank(behind)):
			behind = tower
	if behind != null and purchases.get(behind, 0) < int(options.depth):
		await _buy_next(level, behind)
		return

	#element walls, now and then: the shared line to Up 2, then a random element on a random plain wall
	if walls >= WALL_ELEMENT_MIN_WALLS and randf() < WALL_ELEMENT_CHANCE and _buy_wall_step(level):
		return

	var trap_name : String = _next_trap()
	if traps < int(options.traps) and traps * 4 < towers.size() and _is_unlocked(trap_name):
		if level.player_stats.has_enough_gold(_price_of(trap_name)):
			var trap_cell : Vector2i = _best_trap_cell(level, trap_name)
			if trap_cell != Vector2i.MAX:
				await _place(kit, level, trap_name, trap_cell)
				traps += 1
		return

	#no free cell left for a tower: the gold goes to upgrades instead
	if towers.size() < tower_cap and await _place_tower(kit, level):
		return
	if behind != null:
		await _buy_next(level, behind)


## False when there is no cell left for the next tower (not enough gold only waits).
func _place_tower(kit : TestKit, level : Level) -> bool:
	var types : Array[String] = _tower_types()
	if type_order.is_empty():
		for type in types.size():
			type_order.append(type)
		if options.order == "shuffle":
			type_order.shuffle()
	#only a waiting Keeper left in this round of types: start the next round (it would rotate on its own forever)
	if not type_order.any(func(order : int) -> bool: return _is_wanted_now(types[order])):
		for order in types.size():
			type_order.append(order)
	#the next type it can afford goes first: waiting for a dear one before the first wave waits forever (no gold comes
	#in until a wave starts; an Elder Drake first stalled level 1, 2026-11-25)
	for index in type_order.size():
		if not _is_wanted_now(types[type_order[index]]):
			continue
		if level.player_stats.has_enough_gold(_placement_price(level, types[type_order[index]])):
			if index > 0:
				type_order.push_front(type_order.pop_at(index))
			break
	#nothing wanted is affordable yet: wait for the first wanted type, never place an extra over the core
	if not _is_wanted_now(types[type_order[0]]):
		for index in type_order.size():
			if _is_wanted_now(types[type_order[index]]):
				type_order.push_front(type_order.pop_at(index))
				break
	var type : int = type_order[0]
	var scene_name : String = types[type]
	if not level.player_stats.has_enough_gold(_placement_price(level, scene_name)):
		return true
	var cell : Vector2i = Vector2i.MAX
	if scene_name == BUFFER:
		#a Buffer waits for towers to drum up; meanwhile the next type goes first
		cell = _best_buffer_cell(level)
		if cell == Vector2i.MAX:
			type_order.pop_front()
			return true
	elif scene_name == HOARD:
		#gold before guns lost wave 1 on 10 and 12 (2026-11-26): a Keeper waits for HOARD_MIN_TOWERS shooting towers
		#(false: the gold goes to upgrades; true would wait for nothing before wave 1, no gold comes in then)
		if towers.size() < HOARD_MIN_TOWERS:
			type_order.push_back(type_order.pop_front())
			return false
		cell = _keeper_cell(level)
	else:
		cell = _best_tower_cell(level, _range_of(scene_name), _min_range_of(scene_name), scene_name)
	if cell == Vector2i.MAX:
		return false
	type_order.pop_front()
	var tower : Building = await _place(kit, level, scene_name, cell)
	var leaf : String = build.leaf if build.has("leaf") else LEAVES[(TOWERS.find(scene_name) + int(options.rotation)) % LEAVES.size()]
	tower.set_meta(LEAF_META, leaf)
	tower.set_meta(RANGE_META, _range_of(scene_name))
	towers.append(tower)
	purchases[tower] = 0
	return true


## False for a Hoard Keeper before HOARD_MIN_TOWERS shooting towers stand (gold before guns), and for a type past
## the core while the core has fewer than EXTRA_PER_CORE towers per extra one.
func _is_wanted_now(scene_name : String) -> bool:
	if scene_name == HOARD and towers.size() < HOARD_MIN_TOWERS:
		return false
	var types : Array[String] = _tower_types()
	if types.find(scene_name) < CORE_TYPES:
		return true
	var core : int = 0
	var extra : int = 0
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		if types.find(tower.scene_file_path.get_file().get_basename()) < CORE_TYPES:
			core += 1
		else:
			extra += 1
	return (extra + 1) * EXTRA_PER_CORE <= core


## How far along a tower counts when the bot picks the least upgraded one: support towers count double.
func _upgrade_rank(tower : Building) -> int:
	var bought : int = purchases.get(tower, 0)
	return bought * SUPPORT_UPGRADE_WEIGHT if tower is HoardKeeper or tower is Buffer else bought


#PlayerStats takes the price itself when the building is placed
func _place(kit : TestKit, level : Level, scene_name : String, cell : Vector2i) -> Building:
	var price : float = _placement_price(level, scene_name)
	gold_spent += price
	if scene_name == WALL:
		wall_gold += price
	return await kit.place(scene_name, cell)


#the base price plus the tower price step for every stepped building on the map
func _placement_price(level : Level, scene_name : String) -> float:
	var key : String = scene_name + "_step"
	if not prices.has(key):
		var instance : Building = load(TestKit.BUILDING_PATH % scene_name).instantiate()
		prices[key] = instance.price_step
		instance.free()
	return _price_of(scene_name) + UpgradeRules.price_step_extra(prices[key], level.get_price_step_count())


## Buys the tower's next upgrade, its element leaf when it is the evolve step.
func _buy_next(level : Level, tower : Building) -> void:
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	upgrades._on_unit_selected(tower)
	var offered : Array[GoldUpgradeOption] = upgrades.options
	if offered.is_empty():
		return
	var index : int = 0
	for o in offered.size():
		if str(offered[o].element_leaf_path).ends_with(tower.get_meta(LEAF_META, "")):
			index = o
	var gold_before : float = level.player_stats.gold
	upgrades._on_gold_upgrade_pressed(index)
	if level.player_stats.gold < gold_before:
		gold_spent += gold_before - level.player_stats.gold
		purchases[tower] = purchases.get(tower, 0) + 1


func _has_options(level : Level, tower : Building) -> bool:
	level.building_type_upgrades._on_unit_selected(tower)
	#a tier whose talent is not learned is shown locked, never bought
	return level.building_type_upgrades.options.any(func(o : GoldUpgradeOption) -> bool: return not o.is_locked)


## The free cell, off the routes, whose aura reaches the most of the bot's other towers (at least BUFFER_MIN_TOWERS);
## Vector2i.MAX when there is none yet.
func _best_buffer_cell(level : Level) -> Vector2i:
	var placed : Array[Building] = []
	for tower in towers:
		if is_instance_valid(tower) and not tower is Buffer:
			placed.append(tower)
	if placed.size() < BUFFER_MIN_TOWERS:
		return Vector2i.MAX
	var on_route : Dictionary[Vector2i, bool] = {}
	for cell in _route_cells(level):
		on_route[cell] = true
	var reach : float = _range_of(BUFFER) + 0.25
	var best : Vector2i = Vector2i.MAX
	var best_count : int = BUFFER_MIN_TOWERS - 1
	var region : Rect2i = level.grid.astar_grid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell : Vector2i = Vector2i(x, y)
			if on_route.has(cell) or not _is_free_to_build(level, cell):
				continue
			var count : int = 0
			for tower in placed:
				if Vector2(tower.grid_position - cell).length() <= reach:
					count += 1
			if count > best_count:
				best_count = count
				best = cell
	return best


## The free cell, off the routes, that has the most route cells in range; nearer the castle on a tie.
#min_range_tiles: route cells closer than this are out of reach (the Mortar); scene_name: the tower, whose synergy
#partners nearby count as SYNERGY_CELLS route cells each (_synergy_cells)
func _best_tower_cell(level : Level, range_tiles : float, min_range_tiles : float = 0.0, scene_name : String = "") -> Vector2i:
	var partners : Array[Dictionary] = _synergy_partners(level, scene_name, range_tiles)
	var route_cells : Array[Vector2i] = _route_cells(level)
	var on_route : Dictionary[Vector2i, bool] = {}
	for cell in route_cells:
		on_route[cell] = true
	var castle : Vector2i = level.grid.world_position_to_grid(level.end_point.global_position)
	var best : Vector2i = Vector2i.MAX
	var best_score : float = 0.0
	var region : Rect2i = level.grid.astar_grid.region
	var reach : float = range_tiles * range_tiles
	var too_near : float = min_range_tiles * min_range_tiles
	#a tower touching a wall makes the route cells beside it maze: worth a spot by the walls
	var hold : float = _maze_hold(level)
	var maze : Dictionary[Vector2i, bool] = _maze_cells(level)
	var walls : Dictionary[Vector2i, bool] = {}
	for building in level.all_buildings:
		if is_instance_valid(building) and building.is_placed and building is Wall:
			walls[building.grid_position] = true
	#the tower's niche: corridors for a Breather, corners for a Nova, the maze for a Spotter, slow cells for a Mortar
	var niches : Dictionary[Vector2i, float] = NICHES.route_factors(level.grid, NICHES.key_of_scene(scene_name), route_cells, maze, _build_element_name())

	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell : Vector2i = Vector2i(x, y)
			if on_route.has(cell) or not _is_free_to_build(level, cell):
				continue
			var covered : float = 0.0
			var touches_wall : bool = _touches_any(level, cell, walls)
			for route_cell in route_cells:
				var distance : float = Vector2(route_cell - cell).length_squared()
				if distance <= reach and distance >= too_near:
					covered += (hold if maze.has(route_cell) or (touches_wall and distance <= 1.0) else 1.0) * niches.get(route_cell, 1.0)
			var score : float = covered - Vector2(cell - castle).length() * 0.01
			if covered > 0:
				score += _synergy_cells(partners, cell)
			if covered > 0 and score > best_score:
				best_score = score
				best = cell
	return best


## The placed buildings a new tower of this scene works with (design doc Synergies), each with the distance it
## must be within: Spotter and Harpooner by a Mortar (Spotted shells, Pinned target) and the reverse, an Elder by a
## Hoard Keeper (Hoard Guardian), a Hatchery over a trap (Hold the line), a Breather by a Fire wall (Firebreath
## corridor).
func _synergy_partners(level : Level, scene_name : String, range_tiles : float) -> Array[Dictionary]:
	var partners : Array[Dictionary] = []
	for building in level.all_buildings:
		if not is_instance_valid(building) or not building.is_placed:
			continue
		var key : String = _type_of(building)
		var reach : float = -1.0
		match scene_name:
			"puffe_spotter", "puffe_harpooner":
				if key == "PuffeMortar":
					reach = range_tiles + _range_of("puffe_mortar")
			"puffe_mortar":
				if key in ["PuffeSpotter", "PuffeHarpooner"]:
					reach = range_tiles + _range_of("puffe_spotter" if key == "PuffeSpotter" else "puffe_harpooner")
			"puffe_elder":
				if building is HoardKeeper:
					reach = Synergies.HOARD_GUARD_TILES
			"puffe_hatchery":
				if building is Trap:
					reach = range_tiles
			"puffe_breather":
				if building is Wall and building.element == Utils.Element.Fire:
					reach = range_tiles
		if reach >= 0.0:
			partners.append({"cell": building.grid_position, "reach": reach * 0.5 if key in ["PuffeMortar", "PuffeSpotter", "PuffeHarpooner"] else reach})
	return partners


#Spotter and Mortar count as partners when they stand within half their summed reach: their reaches overlap well
func _synergy_cells(partners : Array[Dictionary], cell : Vector2i) -> float:
	var cells : float = 0.0
	for partner in partners:
		if Vector2(cell - partner.cell).length() <= partner.reach:
			cells += SYNERGY_CELLS
	return minf(cells, SYNERGY_CELLS * 2.0)


## The route cell the most towers reach; a trap (trap_name) likes a cell beside a trap of another kind (Trap line
## and the trap pairs: Pinned, Shrapnel bed, Bait), worth TRAP_PAIR_SCORE towers.
func _best_trap_cell(level : Level, trap_name : String = "") -> Vector2i:
	var others : Array[Vector2i] = []
	if not trap_name.is_empty():
		for building in level.all_buildings:
			if is_instance_valid(building) and building is Trap and building.is_placed and building.scene_file_path.get_file().get_basename() != trap_name:
				others.append(building.grid_position)
	var best : Vector2i = Vector2i.MAX
	var best_score : float = 0.0
	#a trap in the maze hits harder (TowerNiches.TRAP_MAZE_BONUS)
	var maze : Dictionary[Vector2i, bool] = _maze_cells(level)
	for cell in _route_cells(level):
		if not _is_free_to_build(level, cell):
			continue
		var score : float = _trap_cell_score(cell)
		if score > 0 and others.any(func(other : Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) <= 1):
			score += TRAP_PAIR_SCORE
		score *= NICHES.cell_factor(level.grid, NICHES.TRAPS[0], cell, maze)
		if score > best_score:
			best_score = score
			best = cell
	return best


## How many of the bot's towers reach this cell.
func _trap_cell_score(cell : Vector2i) -> int:
	var score : int = 0
	for tower in towers:
		if is_instance_valid(tower) and Vector2(tower.grid_position - cell).length() <= _range_of(TOWERS[0]):
			score += 1
	return score


## A Hoard Keeper's cell: off the routes within reach of an Elder Drake that has room for its bonus (Hoard
## Guardian), nearest the Elder; else the first free cell off the routes.
func _keeper_cell(level : Level) -> Vector2i:
	var on_route : Dictionary[Vector2i, bool] = {}
	for cell in _route_cells(level):
		on_route[cell] = true
	var reach : int = int(Synergies.HOARD_GUARD_TILES)
	var best : Vector2i = Vector2i.MAX
	var best_distance : float = INF
	for elder in level.all_buildings:
		if not is_instance_valid(elder) or not elder is ElderDrake or not elder.is_placed:
			continue
		if level.synergies != null and level.synergies.get_bonus(elder, &"hoard") >= Synergies.HOARD_GUARD_BONUS * Synergies.HOARD_GUARD_MOST - 0.001:
			continue
		for x in range(-reach, reach + 1):
			for y in range(-reach, reach + 1):
				var cell : Vector2i = elder.grid_position + Vector2i(x, y)
				var distance : float = Vector2(x, y).length()
				if distance <= Synergies.HOARD_GUARD_TILES and distance < best_distance and not on_route.has(cell) and _is_free_to_build(level, cell):
					best = cell
					best_distance = distance
	return best if best != Vector2i.MAX else _free_cell_off_route(level)


## The route cell that, as a wall, keeps the most route cells in the towers' reach, then makes the
## routes longest, without closing any route. A wall never pulls the route away from the towers.
func _best_wall_cell(level : Level) -> Vector2i:
	var best : Vector2i = Vector2i.MAX
	var hold : float = _maze_hold(level)
	var best_score : float = _wall_score(_open_routes(level), _maze_cells(level), hold)
	var ends : Dictionary[Vector2i, bool] = {}
	for spawner in level.get_spawners():
		ends[level.grid.world_position_to_grid(spawner.global_position)] = true
		ends[level.grid.world_position_to_grid(spawner.end_point.global_position)] = true

	for cell in _route_cells(level):
		if ends.has(cell) or not _is_free_to_build(level, cell):
			continue
		level.grid.set_cell_weight(cell, BLOCKED_WEIGHT)
		var routes : Array[Array] = _open_routes(level)
		level.grid.set_cell_weight(cell, 1.0)
		if routes.is_empty():
			continue
		var score : float = _wall_score(routes, _maze_cells(level, [cell]), hold)
		if score > best_score:
			best_score = score
			best = cell
	return best


#route cells in each tower's reach (a cell two towers reach counts twice) count far more than the
#route's length, so a wall never trades one tower's time on the enemies for another's; a maze cell (slowed)
#counts hold times, since the enemies stay that much longer in reach
func _wall_score(routes : Array[Array], maze : Dictionary[Vector2i, bool], hold : float) -> float:
	var covered : float = 0.0
	var length : int = 0
	for route in routes:
		length += route.size()
		for cell in route:
			var weight : float = hold if maze.has(cell) else 1.0
			for tower in towers:
				if is_instance_valid(tower) and Vector2(tower.grid_position - cell).length_squared() <= tower.get_meta(RANGE_META, 0.0) ** 2:
					covered += weight
	return covered * WALL_COVER_WEIGHT + length


## The maze cells (LevelGrid.is_maze_cell, 2026-11-26): beside a wall, or beside a building (not a trap) that
## touches a wall; extra_walls are walls the bot is weighing, counted as placed.
func _maze_cells(level : Level, extra_walls : Array = []) -> Dictionary[Vector2i, bool]:
	var walls : Dictionary[Vector2i, bool] = {}
	for cell : Vector2i in extra_walls:
		walls[cell] = true
	var others : Array[Vector2i] = []
	for building in level.all_buildings:
		if not is_instance_valid(building) or not building.is_placed or building is Trap:
			continue
		if building is Wall:
			walls[building.grid_position] = true
		else:
			others.append(building.grid_position)
	var maze : Dictionary[Vector2i, bool] = {}
	for cell in walls:
		for neighbour in level.grid.get_surrounding_cells(cell):
			maze[neighbour] = true
	for cell in others:
		if _touches_any(level, cell, walls):
			for neighbour in level.grid.get_surrounding_cells(cell):
				maze[neighbour] = true
	return maze


func _touches_any(level : Level, cell : Vector2i, cells : Dictionary[Vector2i, bool]) -> bool:
	for neighbour in level.grid.get_surrounding_cells(cell):
		if cells.has(neighbour):
			return true
	return false


## How much longer an enemy stays on a maze cell (the maze slow, cards and talents in).
func _maze_hold(level : Level) -> float:
	return 1.0 / maxf(level.grid.maze_speed_factor - level.grid.talent_maze_slow, 0.4)


#every route's cells, or none when one has to go through a building
func _open_routes(level : Level) -> Array[Array]:
	var routes : Array[Array] = []
	var ids : Dictionary[int, bool] = _active_spawner_ids(level)
	for spawner in level.get_spawners():
		if not ids.is_empty() and not ids.has(spawner.id):
			continue
		var from : Vector2i = level.grid.world_position_to_grid(spawner.global_position)
		var to : Vector2i = level.grid.world_position_to_grid(spawner.end_point.global_position)
		var path : Array[Vector2i] = level.grid.astar_grid.get_id_path(from, to)
		for cell in path:
			if level.grid.astar_grid.get_point_weight_scale(cell) >= BLOCKED_WEIGHT:
				return []
		routes.append(path)
	return routes


func _route_length(level : Level) -> int:
	var total : int = 0
	for path in _paths(level):
		total += path.size()
	return total


func _route_cells(level : Level) -> Array[Vector2i]:
	var cells : Dictionary[Vector2i, bool] = {}
	for path in _paths(level):
		for point in path:
			cells[level.grid.world_position_to_grid(point)] = true
	return cells.keys()


#the routes of the spawners the coming (or running) wave uses, so the gold goes where the enemies walk
func _paths(level : Level) -> Array[PackedVector2Array]:
	var ids : Dictionary[int, bool] = _active_spawner_ids(level)
	if cached_paths.is_empty() or cached_ids != ids:
		cached_paths.clear()
		cached_ids = ids
		for spawner in level.get_spawners():
			if ids.is_empty() or ids.has(spawner.id):
				cached_paths.append(level.grid.find_path(spawner.global_position, spawner.end_point.global_position))
				#waders leave a long maze for a crossing (Magma Heart's salamanders): cover their way too
				if not level.grid.bog_crossings.is_empty():
					var wading : WadingRoute = level.grid.find_wading_route(spawner.global_position, spawner.end_point.global_position)
					if wading.crossing != null:
						cached_paths.append(wading.path)
	return cached_paths


func _active_spawner_ids(level : Level) -> Dictionary[int, bool]:
	var runner : WaveRunner = level.wave_runner
	var index : int = runner.current_wave_index if runner.is_spawning or not level.existing_enemies.is_empty() else runner.current_wave_index + 1
	var ids : Dictionary[int, bool] = {}
	if index >= 0 and index < runner.waves.size():
		for group in runner.waves[index].spawn_groups:
			ids[group.spawner_id] = true
	return ids


func _is_free_to_build(level : Level, cell : Vector2i) -> bool:
	return level.grid.is_position_buildable(level.grid.grid_position_to_world(cell)) and not level.grid.has_building_in_cell_position(cell)


## One wall step it can afford: an element for a plain wall when the line offers them, else the line's next
## upgrade up to Up 2; true when it bought one.
func _buy_wall_step(level : Level) -> bool:
	var plain : Array[Wall] = []
	for building in level.all_buildings:
		if is_instance_valid(building) and building is Wall and building.is_placed and not building.is_dead and building.element == Utils.Element.None:
			plain.append(building)
	if plain.is_empty():
		return false
	var wall : Wall = plain.pick_random()
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	upgrades._on_unit_selected(wall)
	var choices : Array[int] = []
	for index in upgrades.options.size():
		var option : GoldUpgradeOption = upgrades.options[index]
		if option.wall_element != Utils.Element.None and option.is_affordable:
			choices.append(index)
	if choices.is_empty() and upgrades.get_upgrade_steps(wall) < BuildingTypeUpgrades.WALL_ELEMENT_MIN_UPGRADES:
		for index in upgrades.options.size():
			var option : GoldUpgradeOption = upgrades.options[index]
			if option.wall_element == Utils.Element.None and not option.is_evolve and option.is_affordable:
				choices.append(index)
				break
	if choices.is_empty():
		return false
	var gold_before : float = level.player_stats.gold
	upgrades._on_gold_upgrade_pressed(choices.pick_random())
	var spent : float = gold_before - level.player_stats.gold
	gold_spent += spent
	wall_gold += spent
	return spent > 0.0


## The trap the bot builds next (option trap): mixed takes turns between the unlocked traps, Leopard Trap first.
func _next_trap() -> String:
	if options.trap in [TRAP, EGG_BOMB, SPIKE_FIELD]:
		return options.trap
	var unlocked : Array[String] = []
	for trap_name in [TRAP, EGG_BOMB, SPIKE_FIELD]:
		if _is_unlocked(trap_name):
			unlocked.append(trap_name)
	return unlocked[traps % unlocked.size()] if not unlocked.is_empty() else TRAP


## The first free cell off every route (scanning from the castle side is not needed: it covers nothing).
func _free_cell_off_route(level : Level) -> Vector2i:
	var on_route : Dictionary[Vector2i, bool] = {}
	for cell in _route_cells(level):
		on_route[cell] = true
	var region : Rect2i = level.grid.astar_grid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell : Vector2i = Vector2i(x, y)
			if not on_route.has(cell) and _is_free_to_build(level, cell):
				return cell
	return Vector2i.MAX


func _price_of(scene_name : String) -> float:
	if not prices.has(scene_name):
		prices[scene_name] = _base_stat(scene_name, Utils.StatType.Price)
	return prices[scene_name]


func _range_of(scene_name : String) -> float:
	var key : String = scene_name + "_range"
	if not prices.has(key):
		#the skill's range, or the unit's when the skill has none
		var instance : Node = load(TestKit.BUILDING_PATH % scene_name).instantiate()
		var range_tiles : float = 0.0
		for stats in instance.find_children("*", "Stats", true, false):
			for stat in stats.get_children():
				if stat is Stat and stat.type == Utils.StatType.AttackRange:
					range_tiles = maxf(range_tiles, stat.base_value)
		instance.free()
		prices[key] = range_tiles
	return prices[key]


func _min_range_of(scene_name : String) -> float:
	var key : String = scene_name + "_min_range"
	if not prices.has(key):
		var instance : Node = load(TestKit.BUILDING_PATH % scene_name).instantiate()
		prices[key] = (instance as Tower).min_range_tiles if instance is Tower else 0.0
		instance.free()
	return prices[key]


func _base_stat(scene_name : String, type : Utils.StatType) -> float:
	var instance : Node = load(TestKit.BUILDING_PATH % scene_name).instantiate()
	var value : float = 0.0
	for stat in instance.get_node("Stats").get_children():
		if stat is Stat and stat.type == type:
			value = stat.base_value
	instance.free()
	return value


func _on_enemy_spawned(enemy : Enemy) -> void:
	_add(spawned, _type_of(enemy), 1)
	LevelModeData.scale_health(enemy, float(options.health))
	var speed_factor : float = float(options.speed)
	if not is_equal_approx(speed_factor, 1.0):
		var faster : ModifierData = ModifierData.new()
		faster.stat_type = Utils.StatType.Speed
		faster.calculate_type = Utils.ModifyType.Multiply
		faster.value = speed_factor - 1.0
		enemy.modifier_manager.add_modifier(faster)


func _on_enemy_hit(enemy : Enemy, hit : DamageData) -> void:
	if hit.damage <= 0.0:
		return
	var source : String = _type_of(hit.source) if is_instance_valid(hit.source) else "none"
	if hit.is_reaction:
		source += " reaction"
	elif hit.is_overtime:
		source += " effects"
	_add(tower_damage, source, hit.damage)
	if not hit.is_reaction and not hit.is_overtime:
		var hits : Array = wave_hits.get_or_add(current_wave, [0, 0.0, 0.0])
		hits[0] += 1
		hits[1] += hit.damage
		hits[2] = maxf(hits[2], hit.damage)
	_add(enemy_damage, _type_of(enemy), hit.damage)
	if smart != null:
		smart.on_hit(hit)


## The build's element by name ("" for the mixed bot, whose towers take turns), for the niches a Frost tower makes.
func _build_element_name() -> String:
	if not build.has("element"):
		return ""
	return str(Utils.Element.find_key(build.element))


func _type_of(node : Node) -> String:
	return String(node.name).rstrip(DIGITS)


func _add(totals : Dictionary, key : String, amount : float) -> void:
	totals[key] = totals.get(key, 0) + amount


func _rounded(totals : Dictionary[String, float]) -> Dictionary[String, int]:
	var out : Dictionary[String, int] = {}
	for key in totals:
		out[key] = roundi(totals[key])
	return out


func _is_unlocked(building_name : String) -> bool:
	if options.unlocked == "all":
		return true
	var element : BuildingListElement = load(BUILDING_LIST_PATH % building_name)
	return element.is_unlocked(int(options.level))
