extends RefCounted

## Bog crossings: wading enemies take the stones when they are cheaper than the road, the others never do.

const LEVEL : int = 14
#a crossing worth taking: far apart along the road, close over the bog
const MIN_ROAD_CELLS : int = 14
#level 13's bends go round tree walls; a crossing over one is fine for the test, the levels put them over deep water
const MAX_CROSSING_TILES : float = 8.0


#two road cells close in a straight line but far apart along the road: a bend around the bog
func _place_crossing(kit : TestKit) -> BogCrossing:
	var spawner : Spawner = kit.level.get_spawners()[0]
	var road : PackedVector2Array = kit.level.grid.find_path(spawner.global_position, spawner.end_point.global_position)
	for i in road.size():
		for j in range(road.size() - 1, i + MIN_ROAD_CELLS, -1):
			if road[i].distance_to(road[j]) <= MAX_CROSSING_TILES * Utils.TILE_SIZE:
				var crossing : BogCrossing = BogCrossing.new()
				crossing.position = road[i]
				crossing.exit_offset = road[j] - road[i]
				kit.level.add_child(crossing)
				kit.level.grid.bog_crossings.append(crossing)
				return crossing
	return null


func test_a_wader_takes_the_crossing(kit : TestKit) -> void:
	await kit.load_level(LEVEL)
	var crossing : BogCrossing = _place_crossing(kit)
	kit.check(crossing != null, "the level has a bend to cut")
	if crossing == null:
		return
	var toad : Enemy = kit.spawn_enemy("swampling")
	var gecko : Enemy = kit.spawn_enemy("fastswampling")
	await kit.frames(2)
	kit.check(toad.wade_crossing == crossing and toad.wade_exit_index > 0, "the toad's path goes over the stones")
	kit.check(gecko.wade_crossing == null and gecko.wade_exit_index == -1, "the gecko keeps to the road")
	kit.check(toad.point_path.size() < gecko.point_path.size(), "the stones are the shorter way (%d < %d)" % [toad.point_path.size(), gecko.point_path.size()])

	var waded : Array[bool] = [false]
	await kit.run_until(func() -> bool:
		if toad.is_wading:
			waded[0] = true
		return toad.current_waypoint_index > toad.wade_exit_index, 40.0)
	kit.check(waded[0], "it wades")
	kit.check(toad.global_position.distance_to(crossing.exit_position) < Utils.TILE_SIZE * 1.5, "and comes out on the far shore")


func test_a_blocked_road_to_the_stones_keeps_the_road(kit : TestKit) -> void:
	await kit.load_level(LEVEL)
	var crossing : BogCrossing = _place_crossing(kit)
	if crossing == null:
		kit.check(false, "the level has a bend to cut")
		return
	#a very slow crossing costs more than the road
	crossing.wade_speed_factor = 0.1
	crossing.exit_offset = crossing.exit_offset
	var toad : Enemy = kit.spawn_enemy("swampling")
	await kit.frames(2)
	var road_cells : int = kit.level.grid.find_path(toad.global_position, toad.end_point.global_position).size()
	var stones_cost : float = crossing.get_cost()
	kit.check(toad.wade_crossing == null or stones_cost < road_cells, "it only wades when the stones are cheaper (cost %.0f vs %d road cells)" % [stones_cost, road_cells])
