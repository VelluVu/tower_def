extends RefCounted

## The rare mechanic cards: Ricochet (Bolter), Echo Pulse (Nova), Chain Beam (Beamer), and the rarity draw.

const FakeProjectile : GDScript = preload("res://tools/test/fake_projectile.gd")
const BOLT_SCENE : String = "res://scenes/unit/skills/projectiles/homing_physical_bolt.tscn"
const TOWER_CELL : Vector2i = Vector2i(12, 6)


func test_each_card_fits_only_its_tower(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", Vector2i(10, 6))
	var nova : Building = await kit.place("puffe_nova", Vector2i(14, 6))
	var beamer : Building = await kit.place("puffe_beamer", Vector2i(16, 6))
	var cards : Dictionary[String, Building] = {"ricochet": bolter, "echo_pulse": nova, "chain_beam": beamer}
	for card_name in cards:
		var card : EvolveResource = load(TestKit.CARD_PATH % card_name)
		kit.check(card.rarity == EvolveResource.Rarity.Rare, "%s is rare" % card_name)
		for building : Building in [bolter, nova, beamer]:
			kit.check(kit.level.upgrades._fits(card, building, 2) == (building == cards[card_name]), "%s fits %s: %s" % [card_name, building.name, building == cards[card_name]])


func test_rare_cards_are_drawn_less_often(kit : TestKit) -> void:
	var common : EvolveResource = load(TestKit.CARD_PATH % "attack_speed")
	var rare : EvolveResource = load(TestKit.CARD_PATH % "ricochet")
	kit.check_near(UpgradeRules.offer_key(common, 0.5), 0.5, "a common card's key is its roll")
	#plain damage cards come up less often too (2026-11-26); a trade-off damage card does not
	kit.check_near(UpgradeRules.offer_weight(load(TestKit.CARD_PATH % "damage")), UpgradeRules.DAMAGE_OFFER_WEIGHT, "a damage card's weight")
	kit.check_near(UpgradeRules.offer_weight(load(TestKit.CARD_PATH % "projectile_damage")), UpgradeRules.DAMAGE_OFFER_WEIGHT, "a skill damage card's weight")
	kit.check_near(UpgradeRules.offer_weight(load(TestKit.CARD_PATH % "heavy_blows")), 1.0, "a trade-off card keeps its weight")
	kit.check(UpgradeRules.offer_key(rare, 0.5) < 0.2, "a rare card's key is lower for the same roll")
	#against one common card, a rare one wins the draw weight / (weight + 1) of the time
	var wins : int = 0
	for i in 2000:
		if UpgradeRules.offer_key(rare, randf_range(0.0001, 1.0)) > UpgradeRules.offer_key(common, randf_range(0.0001, 1.0)):
			wins += 1
	var expected : float = UpgradeRules.RARE_OFFER_WEIGHT / (UpgradeRules.RARE_OFFER_WEIGHT + 1.0)
	kit.check_near(wins / 2000.0, expected, "rare draw share", 0.04)


func test_ricochet_bounces_to_the_next_enemy(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", TOWER_CELL)
	kit.pick_card("ricochet")
	kit.check_near(bolter.stats.get_stat_value(Utils.StatType.Ricochet), 1.0, "the card gives one ricochet")

	var first : Enemy = kit.spawn_enemy("weakling")
	var second : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var bolt : HomingBolt = load(BOLT_SCENE).instantiate()
	kit.level.add_child(bolt)
	var skill_data : SkillData = SkillData.new()
	skill_data.damage_data = bolter.skill.damage_data
	skill_data.target = first
	skill_data.ricochets = 1
	bolt.launch(skill_data)

	var health : float = first.stats.get_stat_value(Utils.StatType.Health)
	bolt._hit(first)
	kit.check(first.stats.get_stat_value(Utils.StatType.Health) < health, "the target takes the hit")
	kit.check(skill_data.target == second and not bolt.is_hit, "the bolt flies on to the next enemy")
	bolt._hit(second)
	kit.check(bolt.is_hit, "no ricochets left: the bolt ends on the second enemy")
	bolt.queue_free()


func test_echo_pulse_launches_again_for_half_damage(kit : TestKit) -> void:
	await kit.load_level(1)
	var nova : Building = await kit.place("puffe_nova", TOWER_CELL)
	var skill : LaunchProjectile = nova.skill
	skill.projectile_scene = FakeProjectile.packed()
	kit.pick_card("echo_pulse")
	#no crits: each launch rolls its own, and one crit would break the half
	var crit : Stat = skill.stats.get_stat(Utils.StatType.CriticalChance)
	if crit != null:
		crit.base_value = 0.0
		crit.value = 0.0
	FakeProjectile.launched_damage.clear()

	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	_park(enemy, nova)
	await kit.run_until(func() -> bool:
		_park(enemy, nova)
		return FakeProjectile.launched_damage.size() >= 2, 5.0)

	var launches : Array[float] = FakeProjectile.launched_damage
	kit.check(launches.size() >= 2, "the attack and its echo")
	if launches.size() >= 2:
		kit.check_near(launches[1], launches[0] * LaunchProjectile.EXTRA_SHOT_DAMAGE_SHARE, "the echo hits for half", 0.02)


func test_chain_beam_hits_a_second_enemy(kit : TestKit) -> void:
	await kit.load_level(1)
	var beamer : Building = await kit.place("puffe_beamer", TOWER_CELL)
	kit.pick_card("chain_beam")
	var first : Enemy = kit.spawn_enemy("weakling")
	var second : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	var second_health : float = second.stats.get_stat_value(Utils.StatType.Health)
	await kit.run_until(func() -> bool:
		_park(first, beamer)
		_park(second, beamer, Vector2(16.0, 16.0))
		return second.stats.get_stat_value(Utils.StatType.Health) < second_health, 5.0)

	kit.check(second.stats.get_stat_value(Utils.StatType.Health) < second_health, "the chained enemy takes damage")
	var beam : Beam = beamer.skill
	kit.check(beam.line.get_point_count() >= 3, "the beam is drawn through the chained enemy")


#keeps an enemy still in the tower's range (a kinematic freeze: range areas don't see a static one)
func _park(enemy : Enemy, tower : Building, offset : Vector2 = Vector2(16.0, 0.0)) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	enemy.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	enemy.freeze = true
	enemy.global_position = tower.global_position + offset


func test_pierce_flies_on_through_its_target(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", TOWER_CELL)
	var first : Enemy = kit.spawn_enemy("weakling")
	var second : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var bolt : HomingBolt = load(BOLT_SCENE).instantiate()
	kit.level.add_child(bolt)
	var skill_data : SkillData = SkillData.new()
	skill_data.damage_data = bolter.skill.damage_data
	skill_data.target = first
	skill_data.pierces = 1
	bolt.launch(skill_data)

	bolt._hit(first)
	kit.check(not bolt.is_hit and bolt.target_is_destroyed, "it pierces: on in a straight line")
	var health : float = second.stats.get_stat_value(Utils.StatType.Health)
	bolt._hit(second)
	kit.check(second.stats.get_stat_value(Utils.StatType.Health) < health, "the enemy behind takes the hit")
	kit.check(bolt.is_hit, "one pierce: it ends on the second enemy")
