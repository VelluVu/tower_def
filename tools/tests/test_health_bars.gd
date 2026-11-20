extends RefCounted

## Enemy health bars and the damage number modes (the user's playtest notes, 2026-10-28; built 2026-11-20).
## Options are set in the store's dictionary, never saved, so the player's settings.cfg stays untouched.


func _set_option(key : String, value : Variant) -> Variant:
	var old : Variant = SettingsManager.get_option(key)
	SettingsManager._options[key] = value
	SettingsManager.option_changed.emit(key, value)
	return old


func _bar(enemy : Enemy) -> EnemyHealthBar:
	return enemy.get_node_or_null(EnemyHealthBar.NODE_NAME) as EnemyHealthBar


func test_bar_shows_once_hurt(kit : TestKit) -> void:
	await kit.load_level(1)
	var old : Variant = _set_option(SettingsManager.OPTION_HEALTH_BARS, true)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var bar : EnemyHealthBar = _bar(enemy)
	kit.check(bar != null, "a spawned enemy gets a health bar")
	kit.check(not bar.visible, "hidden at full health")
	var health : Stat = enemy.stats.get_stat(Utils.StatType.Health)
	health.value = enemy.stats.get_stat_value(Utils.StatType.MaxHealth) * 0.5
	await kit.frames(1)
	kit.check(bar.visible, "shown once hurt")
	kit.check_near(bar.shown_ratio, 0.5, "at half health it is half full")
	kit.check(bar.width >= EnemyHealthBar.MIN_WIDTH and bar.width <= EnemyHealthBar.MAX_WIDTH and bar.width % 2 == 0, "an even width that fits the sprite (%d)" % bar.width)
	kit.check(bar.global_position == bar.global_position.round(), "on whole pixels")
	_set_option(SettingsManager.OPTION_HEALTH_BARS, false)
	await kit.frames(1)
	kit.check(not bar.visible, "the option hides it")
	_set_option(SettingsManager.OPTION_HEALTH_BARS, old)


func test_bosses_keep_their_big_bar(kit : TestKit) -> void:
	await kit.load_level(8)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	kit.check(_bar(boss) == null, "the Broodmother gets no small bar")


func test_crits_only_damage_numbers(kit : TestKit) -> void:
	await kit.load_level(1)
	var old_on : Variant = _set_option(SettingsManager.OPTION_DAMAGE_NUMBERS, true)
	var old_crits : Variant = _set_option(SettingsManager.OPTION_DAMAGE_NUMBERS_CRITS_ONLY, true)
	var manager : DamageNumberManager = DamageNumberManager.new()
	kit.root.add_child(manager)
	var hit : DamageData = DamageData.new()
	hit.damage = 5.0
	manager._on_damage_taken(Vector2.ZERO, hit)
	kit.check(manager.spawned_count == 0, "a plain hit shows no number")
	hit.is_critical = true
	manager._on_damage_taken(Vector2.ZERO, hit)
	kit.check(manager.spawned_count == 1, "a crit does")
	_set_option(SettingsManager.OPTION_DAMAGE_NUMBERS_CRITS_ONLY, false)
	hit.is_critical = false
	manager._on_damage_taken(Vector2.ZERO, hit)
	kit.check(manager.spawned_count == 2, "with All every hit does")
	hit.free()
	manager.queue_free()
	_set_option(SettingsManager.OPTION_DAMAGE_NUMBERS, old_on)
	_set_option(SettingsManager.OPTION_DAMAGE_NUMBERS_CRITS_ONLY, old_crits)
