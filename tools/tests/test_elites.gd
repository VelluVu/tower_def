extends RefCounted

## Elites: tougher, worth more, one affix each, spread evenly through their group.


func _count(kit : TestKit, scene_name : String) -> int:
	return kit.level.existing_enemies.filter(func(e : Enemy) -> bool:
		return is_instance_valid(e) and not e.is_deactivated and e.scene_file_path.get_file().get_basename() == scene_name).size()


func _hit(enemy : Enemy, damage : float) -> void:
	var hit : DamageData = DamageData.new()
	hit.damage = damage
	enemy.take_damage(hit)
	hit.free()


func test_elites_spread_through_the_group(kit : TestKit) -> void:
	var picked : Array[int] = []
	for i in 10:
		if Elite.is_elite_index(i, 10, 3):
			picked.append(i)
	kit.check(picked.size() == 3, "three of ten are elites (%s)" % str(picked))
	kit.check(picked[0] > 0 and picked[2] == 9, "spread, not the first three (%s)" % str(picked))
	kit.check(not Elite.is_elite_index(0, 5, 0), "none when the group has none")


func test_hasted_elite(kit : TestKit) -> void:
	await kit.load_level(1)
	var plain : Enemy = kit.spawn_enemy("weakling")
	var elite_enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	Elite.make(elite_enemy, Elite.Affix.Hasted)
	await kit.frames(1)
	var stat : Callable = func(e : Enemy, t : Utils.StatType) -> float: return e.stats.get_stat_value(t)
	kit.check_near(stat.call(elite_enemy, Utils.StatType.MaxHealth), stat.call(plain, Utils.StatType.MaxHealth) * Elite.HEALTH_MULTIPLIER, "2.5x the health")
	kit.check_near(stat.call(elite_enemy, Utils.StatType.Health), stat.call(elite_enemy, Utils.StatType.MaxHealth), "at full health")
	kit.check_near(stat.call(elite_enemy, Utils.StatType.Price), stat.call(plain, Utils.StatType.Price) * Elite.GOLD_MULTIPLIER, "3x the gold")
	kit.check_near(stat.call(elite_enemy, Utils.StatType.Speed), stat.call(plain, Utils.StatType.Speed) * (1.0 + Elite.HASTE), "40% faster")


func test_shielded_elite_takes_less(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	Elite.make(enemy, Elite.Affix.Shielded)
	await kit.frames(1)
	var before : float = enemy.stats.get_stat_value(Utils.StatType.Health)
	_hit(enemy, 10.0)
	kit.check_near(before - enemy.stats.get_stat_value(Utils.StatType.Health), 6.0, "a 10 hit takes 6")


func test_splitting_elite_leaves_two(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	Elite.make(enemy, Elite.Affix.Splitting)
	await kit.frames(1)
	_hit(enemy, 9999.0)
	await kit.frames(2)
	kit.check(_count(kit, "weakling") == 2, "two copies come out (%d)" % _count(kit, "weakling"))


func test_group_spawns_its_elites(kit : TestKit) -> void:
	await kit.load_level(1)
	var group : SpawnGroupData = SpawnGroupData.new()
	group.enemy_scene = load(TestKit.ENEMY_PATH % "weakling")
	group.count = 4
	group.interval = 0.0
	group.elites = 2
	group.elite_affix = Elite.Affix.Regenerating
	var spawner : Spawner = kit.level.get_spawners()[0]
	spawner.spawn_group(group, func() -> void: pass)
	await kit.frames(2)
	var elites : int = 0
	for child in spawner.get_children():
		if child is Enemy and child.get_node_or_null(Elite.NAME) != null:
			elites += 1
	kit.check(elites == 2, "two of the four are elites (%d)" % elites)


#the elite sheet (tools/sprite/parts/elites.py) replaces the sheet region for region; enemies without one keep theirs
func test_elite_wears_its_elite_sheet(kit : TestKit) -> void:
	await kit.load_level(14)
	var plain : Enemy = kit.spawn_enemy("soldier")
	var elite_enemy : Enemy = kit.spawn_enemy("soldier")
	await kit.frames(1)
	var playing : StringName = elite_enemy.animation_control.animation
	Elite.make(elite_enemy, Elite.Affix.Shielded)
	var after_swap : StringName = elite_enemy.animation_control.animation
	await kit.frames(1)
	var base : SpriteFrames = plain.animation_control.sprite_frames
	var worn : SpriteFrames = elite_enemy.animation_control.sprite_frames
	kit.check(worn != base, "the elite has its own frames")
	kit.check(worn.get_animation_names() == base.get_animation_names(), "with the same animations")
	var walk : StringName = GlobalAnimationNames.WALK_ANIMATION
	var base_texture : AtlasTexture = base.get_frame_texture(walk, 1)
	var worn_texture : AtlasTexture = worn.get_frame_texture(walk, 1)
	kit.check(worn_texture.atlas.resource_path.ends_with("soldier_elite.png"), "on the elite sheet (%s)" % worn_texture.atlas.resource_path)
	kit.check(worn_texture.region == base_texture.region and worn.get_frame_count(walk) == base.get_frame_count(walk), "region for region")
	kit.check(after_swap == playing, "on the animation it was playing (%s, %s)" % [playing, after_swap])
	var second : Enemy = kit.spawn_enemy("soldier")
	await kit.frames(1)
	Elite.make(second, Elite.Affix.Hasted)
	await kit.frames(1)
	kit.check(second.animation_control.sprite_frames == worn, "elites of one kind share the elite frames")

	var weakling : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	var weakling_frames : SpriteFrames = weakling.animation_control.sprite_frames
	Elite.make(weakling, Elite.Affix.Shielded)
	await kit.frames(1)
	kit.check(weakling.animation_control.sprite_frames == weakling_frames, "no elite sheet: the frames stay")
	kit.check(weakling.animation_control.modulate == Elite.TINTS[Elite.Affix.Shielded], "and the full tint shows the elite")
