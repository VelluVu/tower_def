extends RefCounted

## SaveWiring._migrate: older saves follow the levels when one is put in between.


func test_v1_moves_serpent_road_to_13(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 7
	data.level_talent_points = {5: 3, 6: 4}
	wiring._migrate(data, 1)
	kit.check(data.level_progress == 14, "cleared Serpent Road (old 6) is still cleared as 13")
	kit.check(data.level_talent_points.get(5, 0) == 3, "levels before the new ones keep their points")
	kit.check(data.level_talent_points.get(13, 0) == 4, "Serpent Road's points move to 13")
	kit.check(data.level_talent_points.size() == 2, "the new levels have no points yet")
	wiring.free()


func test_v2_moves_the_lair_to_8(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 8
	data.level_talent_points = {6: 2, 7: 5}
	wiring._migrate(data, 2)
	kit.check(data.level_progress == 14, "cleared Serpent Road (7 in version 2) is still cleared as 13")
	kit.check(data.level_talent_points.get(12, 0) == 2, "the lair's points move to 8, then to 12 (version 8)")
	kit.check(data.level_talent_points.get(13, 0) == 5, "Serpent Road's points move to 13")
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
	kit.check(data.level_progress == 8, "the lair (6 in version 2) cleared: Collapsed Tunnels (8 since version 8) is next")
	wiring.free()


func test_v3_moves_the_bridge_to_12(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 10
	data.level_talent_points = {8: 3, 9: 2}
	wiring._migrate(data, 3)
	kit.check(data.level_progress == 13, "cleared the bridge (9 in version 3) is still cleared as 12")
	kit.check(data.level_talent_points.get(12, 0) == 3, "the lair's points go with it to 12 (version 8)")
	kit.check(data.level_talent_points.get(11, 0) == 2, "the bridge's points move to 12, then 11 (version 8)")
	wiring.free()


func test_v4_moves_the_camp_to_36(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 19
	data.level_talent_points = {17: 4, 18: 3}
	data.mode_talent_points = {Utils.LevelMode.Hard: {17: 2, 18: 1}}
	wiring._migrate(data, 4)
	kit.check(data.level_progress == 37, "cleared the camp (18 in version 4) is still cleared as 36")
	kit.check(data.level_talent_points.get(26, 0) == 4, "Haystack Farm's points move to 26")
	kit.check(data.level_talent_points.get(36, 0) == 3 and not data.level_talent_points.has(18), "the camp's points move to 36")
	kit.check(data.mode_talent_points[Utils.LevelMode.Hard].get(36, 0) == 1, "so do its Hard points")
	kit.check(data.mode_talent_points[Utils.LevelMode.Hard].get(26, 0) == 2, "and Haystack Farm's")
	wiring.free()


func test_v4_unlocked_camp_unlocks_the_ford(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 18
	wiring._migrate(data, 4)
	kit.check(data.level_progress == 27, "the camp was next: now Millstream Ford (the first field level added in version 5) is")
	wiring.free()


func test_v5_twelve_per_area(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 16
	data.level_talent_points = {9: 5, 10: 4, 15: 3, 16: 2, 19: 1}
	wiring._migrate(data, 5)
	kit.check(data.level_progress == 25, "Hydra's Mire (15) cleared: the first field level (25) is next")
	kit.check(data.level_talent_points.get(9, 0) == 5, "Collapsed Tunnels stays 9, then 8 (version 8), then 9 again (version 9)")
	kit.check(data.level_talent_points.get(10, 0) == 4, "Lakeshore Watch moves to 11, then 10 (version 8)")
	kit.check(data.level_talent_points.get(24, 0) == 3, "Hydra's Mire moves to 24")
	kit.check(data.level_talent_points.get(25, 0) == 2, "Wheatfield Road moves to 25")
	kit.check(data.level_talent_points.get(28, 0) == 1, "Ashen Village moves to 28")
	wiring.free()


#(2026-11-24): the Broodmother's Lair moves from 8 to 12, the levels between close up
func test_v7_moves_the_lair_to_12(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 20
	data.level_talent_points = {7: 1, 8: 5, 9: 2, 12: 4, 13: 3}
	data.mode_talent_points = {Utils.LevelMode.Hard: {8: 5}}
	data.survival_best_waves = {8: 17}
	wiring._migrate(data, 7)
	kit.check(data.level_progress == 20, "past the Caves: progress stays")
	kit.check(data.level_talent_points.get(12, 0) == 5, "the lair's points move to 12")
	kit.check(data.level_talent_points.get(9, 0) == 2 and data.level_talent_points.get(11, 0) == 4, "9-12 close up to 8-11 (8 swaps on to 9 in version 9)")
	kit.check(data.level_talent_points.get(6, 0) == 1 and data.level_talent_points.get(13, 0) == 3, "levels outside keep theirs (7 swaps to 6 in version 9)")
	kit.check((data.mode_talent_points[Utils.LevelMode.Hard] as Dictionary).get(12, 0) == 5, "Hard points move with the lair")
	kit.check(data.survival_best_waves.get(12, 0) == 17, "and the Survival record")
	wiring.free()


func test_v7_part_way_through_the_caves(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	#cleared 1-10: the lair (8), Collapsed Tunnels (9) and Crystal Deep (10)
	data.level_progress = 11
	data.map_revealed_level = 11
	wiring._migrate(data, 7)
	kit.check(data.level_progress == 10, "Collapsed Tunnels and Crystal Deep stay cleared (8, 9); Lakeshore Watch (10) is next")
	kit.check(data.map_revealed_level == 10, "the map's revealed level follows")
	data.level_progress = 8
	data.map_revealed_level = 8
	wiring._migrate(data, 7)
	kit.check(data.level_progress == 8, "the lair was next: now Collapsed Tunnels is, at the same number")
	wiring.free()


#(2026-11-25): the caves' new route swaps Bat Roost and Echo Crossing (6, 7), Collapsed Tunnels and Crystal Deep (8, 9)
func test_v8_swaps_the_cave_levels(kit : TestKit) -> void:
	var wiring : SaveWiring = SaveWiring.new()
	var data : ProgressData = ProgressData.new()
	data.level_progress = 8
	data.map_revealed_level = 8
	data.level_talent_points = {5: 3, 6: 5, 7: 2, 8: 4, 9: 1, 10: 3}
	data.mode_talent_points = {Utils.LevelMode.Hard: {6: 4}}
	wiring._migrate(data, 8)
	kit.check(data.level_talent_points.get(7, 0) == 5 and data.level_talent_points.get(6, 0) == 2, "6 and 7 swap their points")
	kit.check(data.level_talent_points.get(9, 0) == 4 and data.level_talent_points.get(8, 0) == 1, "so do 8 and 9")
	kit.check(data.level_talent_points.get(5, 0) == 3 and data.level_talent_points.get(10, 0) == 3, "the rest keep theirs")
	kit.check((data.mode_talent_points[Utils.LevelMode.Hard] as Dictionary).get(7, 0) == 4, "Hard points swap too")
	kit.check(data.level_progress == 8 and data.map_revealed_level == 8, "6 and 7 cleared, 8 next: the same numbers")
	wiring.free()
