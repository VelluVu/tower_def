extends RefCounted

## Polish round 10 (2026-11-22): dust puffs when buildings are placed or sold and enemies arrive.


func _puff_count(kit : TestKit) -> int:
	var puffs : DustPuffs = kit.level.get_node(Level.DUST_PUFFS_NAME) as DustPuffs
	return puffs.get_child_count()


func test_placing_and_spawning_puff(kit : TestKit) -> void:
	await kit.load_level(6)
	kit.check(kit.level.get_node_or_null(Level.DUST_PUFFS_NAME) is DustPuffs, "the level has its dust puffs")
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	await kit.place("puffe_bolter", cell)
	kit.check(_puff_count(kit) == 1, "placing a tower puffs")
	kit.spawn_enemy("weakling")
	await kit.frames(1)
	kit.check(_puff_count(kit) == 2, "a walking enemy arriving puffs")
	kit.spawn_enemy("batling")
	await kit.frames(1)
	kit.check(_puff_count(kit) == 2, "a flyer does not")
	await kit.frames(30)
	kit.check(_puff_count(kit) == 0, "puffs free themselves")


func test_same_spot_is_throttled(kit : TestKit) -> void:
	var puffs : DustPuffs = DustPuffs.new()
	kit.root.add_child(puffs)
	puffs.puff(Vector2(100, 100))
	puffs.puff(Vector2(102, 101))
	puffs.puff(Vector2(200, 100))
	kit.check(puffs.get_child_count() == 2, "one puff per spot at a time (%d)" % puffs.get_child_count())
	puffs.queue_free()
