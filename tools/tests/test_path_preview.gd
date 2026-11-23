extends RefCounted

## The route preview: in a build break the next wave's spawn points pulse and the others dim.


func _preview(kit : TestKit) -> PathPreview:
	return kit.level.get_node(Level.PATH_PREVIEW_NAME) as PathPreview


func test_next_wave_spawns_pulse_and_the_others_dim(kit : TestKit) -> void:
	await kit.load_level(12)
	var spawners : Array[Spawner] = kit.level.get_spawners()
	kit.check(spawners.size() >= 2, "the level has more than one spawn point (%d)" % spawners.size())
	if spawners.size() < 2:
		return
	var preview : PathPreview = _preview(kit)
	preview._update_paths()
	kit.check(not preview.next_wave_spawn_ids.is_empty(), "the first wave's spawn points are known before it starts")
	#a wave from the first spawn point only
	var group : SpawnGroupData = SpawnGroupData.new()
	group.spawner_id = spawners[0].id
	var wave : WaveData = WaveData.new()
	wave.spawn_groups = [group]
	var runner : WaveRunner = kit.level.wave_runner
	var old_waves : Array[WaveData] = runner.waves
	runner.waves = [wave]
	preview._update_paths()
	kit.check(preview.next_wave_spawn_ids == [spawners[0].id], "one spawn point pulses (%s)" % [preview.next_wave_spawn_ids])
	kit.check(preview.path_spawn_ids.size() == preview.paths.size(), "every path knows its spawner")
	kit.check(preview._get_spawn_color(spawners[0].id).a == preview.spawn_color.a, "the used one at full colour")
	var other : Spawner = null
	for spawner in spawners:
		if spawner.id != spawners[0].id:
			other = spawner
			break
	if other != null:
		kit.check(preview._get_spawn_color(other.id).a < preview.spawn_color.a, "an unused one dims")
	preview.is_route_visible = false
	kit.check(preview._get_spawn_color(other.id if other != null else -1).a == preview.spawn_color.a, "during a wave every marker is plain")
	runner.waves = old_waves
