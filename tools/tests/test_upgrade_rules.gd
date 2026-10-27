extends RefCounted

## UpgradeRules: the pure maths of cards, XP and gold prices.


func test_capped_bonus(kit : TestKit) -> void:
	kit.check_near(UpgradeRules.capped_bonus(0.3, 0.5, 1.0), 0.3, "below the soft cap counts fully")
	kit.check_near(UpgradeRules.capped_bonus(0.9, 0.5, 1.0), 0.7, "past the soft cap counts at half")
	kit.check_near(UpgradeRules.capped_bonus(2.0, 0.5, 1.0), 1.0, "never above the hard cap")


func test_roll_value(kit : TestKit) -> void:
	var resource : EvolveResource = load(TestKit.CARD_PATH % "damage")
	kit.check_near(UpgradeRules.roll_value(resource, 0.1), resource.modify_value * 3.0, "roll < 0.2 is x3")
	kit.check_near(UpgradeRules.roll_value(resource, 0.3), resource.modify_value * 2.0, "roll < 0.5 is x2")
	kit.check_near(UpgradeRules.roll_value(resource, 0.9), resource.modify_value, "other rolls are x1")


func test_xp_curve(kit : TestKit) -> void:
	var expected : Array[float] = [200.0, 250.0, 350.0, 500.0, 700.0]
	for level in expected.size():
		kit.check_near(UpgradeRules.xp_required(level + 1), expected[level], "xp for level %d" % (level + 1))


func test_kill_xp(kit : TestKit) -> void:
	kit.check_near(UpgradeRules.kill_xp(15.0, 1.0), 30.0, "weakling: 2 xp per max health")
	kit.check_near(UpgradeRules.kill_xp(5.0, 0.4), 4.0, "swarmling: multiplier 0.4")
	var swarmling : Enemy = load("res://scenes/unit/enemy/enemies/swarmling.tscn").instantiate()
	kit.check_near(swarmling.xp_multiplier, 0.4, "the swarmling scene sets its multiplier")
	swarmling.free()


func test_gold_price_rounds_up(kit : TestKit) -> void:
	kit.check_near(UpgradeRules.gold_price(4.0, 0.3), 2.0, "1.2 gold rounds up to 2")
