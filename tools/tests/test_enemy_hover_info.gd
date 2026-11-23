extends RefCounted

## The hover card: which enemy is under the cursor, and what the card says about it.


func _spawn(kit : TestKit, scene_path : String, at : Vector2) -> Enemy:
	var enemy : Enemy = (load(scene_path) as PackedScene).instantiate() as Enemy
	kit.level.add_child(enemy)
	enemy.global_position = at
	return enemy


func test_finds_the_nearest_enemy_under_the_cursor(kit : TestKit) -> void:
	await kit.load_level(1)
	var info : EnemyHoverInfo = kit.level.get_node(EnemyHoverInfo.NODE_NAME) as EnemyHoverInfo
	kit.check(info != null, "the level has the hover card")
	var at : Vector2 = kit.level.end_point.global_position + Vector2(-64, 0)
	var near : Enemy = _spawn(kit, "res://scenes/unit/enemy/enemies/weakling.tscn", at + Vector2(3, 0))
	var far : Enemy = _spawn(kit, "res://scenes/unit/enemy/enemies/weakling.tscn", at + Vector2(8, 0))
	#frozen in place for the check
	near.global_position = at + Vector2(3, 0)
	far.global_position = at + Vector2(8, 0)
	kit.check(info.find_enemy_at(at) == near, "the nearer of two")
	kit.check(info.find_enemy_at(at + Vector2(0, 40)) == null, "nothing far from every enemy")
	near.is_concealed = true
	kit.check(info.find_enemy_at(at) == far, "a hidden enemy is skipped")
	var text : String = EnemyHoverInfo.build_text(far)
	var lines : PackedStringArray = text.split("\n")
	kit.check(lines[0] == far.selectable._get_display_name(), "the title is the selection card's name (%s)" % lines[0])
	kit.check(lines[1].begins_with("Health "), "then the health (%s)" % lines[1])
	near.queue_free()
	far.queue_free()
