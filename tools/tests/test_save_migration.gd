extends RefCounted

## SaveWiring._migrate: older saves follow the levels when one is put in between.


func test_v1_moves_serpent_road_to_12(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 7
	data.level_talent_points = {5: 3, 6: 4}
	wiring._migrate(data, 1)
	kit.check(data.level_progress == 13, "cleared Serpent Road (old 6) is still cleared as 12")
	kit.check(data.level_talent_points.get(5, 0) == 3, "levels before the new ones keep their points")
	kit.check(data.level_talent_points.get(12, 0) == 4, "Serpent Road's points move to 12")
	kit.check(data.level_talent_points.size() == 2, "the new levels have no points yet")
	wiring.free()


func test_v2_moves_the_lair_to_8(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 8
	data.level_talent_points = {6: 2, 7: 5}
	wiring._migrate(data, 2)
	kit.check(data.level_progress == 13, "cleared Serpent Road (7 in version 2) is still cleared as 12")
	kit.check(data.level_talent_points.get(8, 0) == 2, "the lair's points move to 8")
	kit.check(data.level_talent_points.get(12, 0) == 5, "Serpent Road's points move to 12")
	wiring.free()


func test_keeps_a_save_that_only_unlocked_6(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 6
	wiring._migrate(data, 1)
	kit.check(data.level_progress == 6, "the first new cave level is the next level")
	wiring.free()


func test_v2_cleared_lair_unlocks_the_bridge(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 7
	wiring._migrate(data, 2)
	kit.check(data.level_progress == 9, "the lair (6 in version 2) cleared: level 9 is next")
	wiring.free()


func test_v3_moves_the_bridge_to_11(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 10
	data.level_talent_points = {8: 3, 9: 2}
	wiring._migrate(data, 3)
	kit.check(data.level_progress == 12, "cleared the bridge (9 in version 3) is still cleared as 11")
	kit.check(data.level_talent_points.get(8, 0) == 3, "the lair keeps its points")
	kit.check(data.level_talent_points.get(11, 0) == 2, "the bridge's points move to 11")
	wiring.free()
