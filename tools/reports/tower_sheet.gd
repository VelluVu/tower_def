extends RefCounted

## `python tools/gd.py run tools/reports/tower_sheet.gd [seconds=60] [enemy=weakling] [cards=name:value,...]`:
## each tower at Base, Up 2, every element (T1) and Up 3, shooting a parked enemy that never dies.
## Prints measured damage per second (hits and effects apart), the average hit, the crit share,
## and how many hits kill the enemy at its real health.

const TOWERS : PackedStringArray = ["puffe_bolter", "puffe_nova", "puffe_beamer", "leopard_trap"]
const LEAF_NAMES : PackedStringArray = ["PhysicalElementEvolveLeaf", "FireElementEvolveLeaf", "FrostElementEvolveLeaf", "PoisonElementEvolveLeaf"]
const MAIN_SCENE : String = "res://scenes/main.tscn"
const TOWER_CELL : Vector2i = Vector2i(12, 6)
const ENEMY_OFFSET : Vector2 = Vector2(16.0, 0.0)
const ENDLESS_HEALTH : float = 1000000.0
const HEADER : String = "  %-22s %6s %6s %6s %6s %6s %5s %8s"

var _hit_damage : float = 0.0
var _effect_damage : float = 0.0
var _hits : int = 0
var _crits : int = 0


func run(kit : TestKit, args : PackedStringArray) -> void:
	var options : Dictionary = _parse(args)
	var seconds : float = float(options.get("seconds", "60"))
	var enemy_name : String = options.get("enemy", "weakling")
	GameSignals.damage_taken.connect(_on_damage_taken)
	#projectiles go under Utils.game_control: TestKit's stand-in Main is not in the tree, so start the real one
	var main : Main = load(MAIN_SCENE).instantiate()
	kit.root.add_child(main)
	await kit.frames(2)

	print("TOWERS vs %s, %s s each%s" % [enemy_name, seconds, (", cards " + options["cards"]) if options.has("cards") else ""])
	print(HEADER % ["tower / step", "dps", "hit", "effect", "avghit", "crit%", "hits", "to kill"])
	for tower in TOWERS:
		await _measure(kit, options, tower, -1, 0, seconds, enemy_name)
		await _measure(kit, options, tower, -1, 2, seconds, enemy_name)
		for leaf in LEAF_NAMES.size():
			await _measure(kit, options, tower, leaf, 2, seconds, enemy_name)
			await _measure(kit, options, tower, leaf, 3, seconds, enemy_name)


func _measure(kit : TestKit, options : Dictionary, tower : String, leaf : int, ups : int, seconds : float, enemy_name : String) -> void:
	await kit.load_level(1)
	var building : Building = await kit.place(tower, TOWER_CELL)
	if not await _buy_steps(kit, building, leaf, ups):
		kit.free_level()
		return
	_pick_cards(kit, options)

	var enemy : Enemy = kit.spawn_enemy(enemy_name)
	await kit.frames()
	var real_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
	#a kinematic freeze: the range area does not see a statically frozen body
	enemy.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	enemy.freeze = true
	enemy.global_position = building.global_position + ENEMY_OFFSET
	var health : Stat = enemy.stats.get_stat(Utils.StatType.Health)
	_hit_damage = 0.0
	_effect_damage = 0.0
	_hits = 0
	_crits = 0
	await kit.run_until(func() -> bool:
		health.value = ENDLESS_HEALTH
		enemy.global_position = building.global_position + ENEMY_OFFSET
		return false, seconds)

	var avg_hit : float = _hit_damage / maxf(_hits, 1)
	var label : String = "%s %s" % [tower.trim_prefix("puffe_"), _step_name(leaf, ups)]
	print(HEADER % [label, _f((_hit_damage + _effect_damage) / seconds), _f(_hit_damage / seconds), _f(_effect_damage / seconds),
		_f(avg_hit), _f(100.0 * _crits / maxf(_hits, 1)), _hits, _f(real_health / maxf(avg_hit, 0.001))])
	kit.free_level()


## Buys ups upgrades, choosing the element leaf at the evolve step; false when the tower has no such step.
func _buy_steps(kit : TestKit, building : Building, leaf : int, ups : int) -> bool:
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	kit.level.player_stats.gold = 999
	upgrades._on_unit_selected(building)
	var bought : int = 0
	var evolved : bool = leaf < 0
	while bought < ups or not evolved:
		var options : Array[GoldUpgradeOption] = upgrades.options
		if options.is_empty():
			return evolved and bought >= ups
		var index : int = 0
		if options[0].element_leaf_path != NodePath():
			if leaf < 0:
				return bought >= ups
			index = -1
			for i in options.size():
				if str(options[i].element_leaf_path).ends_with(LEAF_NAMES[leaf]):
					index = i
			if index < 0:
				return false
			evolved = true
		else:
			if bought >= ups:
				return evolved
			bought += 1
		upgrades._on_gold_upgrade_pressed(index)
		await kit.frames()
	return true


func _pick_cards(kit : TestKit, options : Dictionary) -> void:
	if not options.has("cards"):
		return
	for entry in str(options["cards"]).split(","):
		var parts : PackedStringArray = entry.split(":")
		kit.pick_card(parts[0], float(parts[1]) if parts.size() > 1 else NAN)


func _on_damage_taken(_position : Vector2, damage_data : DamageData) -> void:
	if damage_data.is_overtime:
		_effect_damage += damage_data.damage
		return
	_hit_damage += damage_data.damage
	_hits += 1
	if damage_data.is_critical:
		_crits += 1


func _step_name(leaf : int, ups : int) -> String:
	if leaf < 0:
		return "Base" if ups == 0 else "Up %d" % ups
	var element : String = LEAF_NAMES[leaf].trim_suffix("ElementEvolveLeaf")
	return "%s T1" % element if ups == 2 else "%s Up %d" % [element, ups]


func _f(value : float) -> String:
	return "%.1f" % value


func _parse(args : PackedStringArray) -> Dictionary:
	var options : Dictionary = {}
	for arg in args:
		var parts : PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	return options
