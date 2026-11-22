extends RefCounted

## Polish round 13 (2026-11-22): hit effects per tower kind and element.


#DamageData is a Node: every hit a test makes is freed at its end (_free_hits)
var _hits : Array[DamageData] = []


func _free_hits() -> void:
	for hit in _hits:
		if is_instance_valid(hit):
			hit.free()
	_hits.clear()


func _hit(source : Node, damage_type : Utils.DamageType, damage : float = 5.0) -> DamageData:
	var data : DamageData = DamageData.new()
	_hits.append(data)
	data.damage_type = damage_type
	data.damage = damage
	data.source = source
	return data


func test_style_by_tower_kind(kit : TestKit) -> void:
	await kit.load_level(6)
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	var bolter : Building = await kit.place("puffe_bolter", cell)
	var nova : Building = await kit.place("puffe_nova", cell + Vector2i(2, 0))
	var beamer : Building = await kit.place("puffe_beamer", cell + Vector2i(4, 0))
	var trap : Building = await kit.place("leopard_trap", cell + Vector2i(6, 0))
	kit.check(HitEffects.get_style(_hit(bolter, Utils.DamageType.Fire)) == HitEffects.BURST, "a Bolter bursts")
	kit.check(HitEffects.get_style(_hit(trap, Utils.DamageType.Physical)) == HitEffects.CLAW, "a trap claws")
	kit.check(HitEffects.get_style(_hit(nova, Utils.DamageType.Frost)) == HitEffects.SPARK and HitEffects.get_style(_hit(beamer, Utils.DamageType.Poison)) == HitEffects.SPARK, "a Nova and a Beamer spark")
	var tick : DamageData = _hit(bolter, Utils.DamageType.Fire)
	tick.is_overtime = true
	var splash : DamageData = _hit(bolter, Utils.DamageType.Fire)
	splash.is_splash = true
	kit.check(HitEffects.get_style(tick) == "" and HitEffects.get_style(_hit(null, Utils.DamageType.Fire)) == "" and HitEffects.get_style(_hit(bolter, Utils.DamageType.Fire, 0.0)) == "", "no effect for ticks, sourceless or empty hits")
	kit.check(HitEffects.get_style(splash) == HitEffects.SPARK, "splash sparks")
	_free_hits()


func test_every_sheet_exists(kit : TestKit) -> void:
	var effects : HitEffects = HitEffects.new()
	var missing : PackedStringArray = []
	for damage_type : Utils.DamageType in HitEffects.ELEMENT_NAMES:
		for style in [HitEffects.BURST, HitEffects.SPARK, HitEffects.CLAW]:
			var sheet : Texture2D = effects.get_sheet(style, damage_type)
			var frame : int = HitEffects.SMALL_FRAME if style == HitEffects.SPARK else HitEffects.BIG_FRAME
			if sheet == null or int(sheet.get_height()) != frame or int(sheet.get_width()) % frame != 0:
				missing.append("%s %s" % [HitEffects.ELEMENT_NAMES[damage_type], style])
	kit.check(missing.is_empty(), "every element has its burst, spark and claw sheet (%s)" % ", ".join(missing))
	effects.free()


func test_hits_play_and_sparks_throttle(kit : TestKit) -> void:
	await kit.load_level(6)
	var effects : HitEffects = kit.level.get_node(Level.HIT_EFFECTS_NAME) as HitEffects
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	var bolter : Building = await kit.place("puffe_bolter", cell)
	var beamer : Building = await kit.place("puffe_beamer", cell + Vector2i(2, 0))
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var crit : DamageData = _hit(bolter, Utils.DamageType.Physical)
	crit.is_critical = true
	GameSignals.enemy_hit.emit(enemy, crit)
	kit.check(effects.get_child_count() == 2, "a crit burst brings its star (%d)" % effects.get_child_count())
	GameSignals.enemy_hit.emit(enemy, _hit(beamer, Utils.DamageType.Fire))
	GameSignals.enemy_hit.emit(enemy, _hit(beamer, Utils.DamageType.Fire))
	kit.check(effects.get_child_count() == 3, "two beam ticks at once spark once (%d)" % effects.get_child_count())
	SettingsManager._options[SettingsManager.OPTION_HIT_EFFECTS] = false
	GameSignals.enemy_hit.emit(enemy, _hit(bolter, Utils.DamageType.Physical))
	kit.check(effects.get_child_count() == 3, "the option turns them off")
	SettingsManager._options[SettingsManager.OPTION_HIT_EFFECTS] = true
	await kit.frames(30)
	kit.check(effects.get_child_count() == 0, "they free themselves")
	_free_hits()


func test_cast_flash_and_element_deaths(kit : TestKit) -> void:
	await kit.load_level(6)
	var effects : HitEffects = kit.level.get_node(Level.HIT_EFFECTS_NAME) as HitEffects
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	var bolter : Building = await kit.place("puffe_bolter", cell)
	var trap : Building = await kit.place("leopard_trap", cell + Vector2i(2, 0))
	await kit.frames(30)
	GameSignals.tower_attacked.emit(bolter.skill)
	kit.check(effects.get_child_count() == 1, "a Bolter firing flashes at its mouth")
	GameSignals.tower_attacked.emit(trap.skill)
	kit.check(effects.get_child_count() == 1, "a trap does not (its claws show on the hit)")
	await kit.frames(30)

	var burnt : Enemy = kit.spawn_enemy("weakling")
	var plain : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var fire_tick : DamageData = _hit(bolter, Utils.DamageType.Fire)
	fire_tick.is_overtime = true
	GameSignals.enemy_hit.emit(burnt, fire_tick)
	GameSignals.enemy_hit.emit(plain, _hit(bolter, Utils.DamageType.Physical))
	await kit.frames(30)
	GameSignals.enemy_destroyed.emit(burnt)
	kit.check(effects.get_child_count() == 1 and (effects.get_child(0) as Sprite2D).texture == effects.get_sheet(HitEffects.DEATH, Utils.DamageType.Fire), "killed by a burn tick: it burns up")
	GameSignals.enemy_destroyed.emit(plain)
	kit.check(effects.get_child_count() == 1, "a physical death keeps its gore only")
	_free_hits()


func test_death_sheets_exist(kit : TestKit) -> void:
	var effects : HitEffects = HitEffects.new()
	for damage_type in [Utils.DamageType.Fire, Utils.DamageType.Frost, Utils.DamageType.Poison]:
		var sheet : Texture2D = effects.get_sheet(HitEffects.DEATH, damage_type)
		kit.check(sheet != null and int(sheet.get_width()) == HitEffects.BIG_FRAME * 4, "%s death: 4 frames" % HitEffects.ELEMENT_NAMES[damage_type])
	for damage_type : Utils.DamageType in HitEffects.ELEMENT_NAMES:
		kit.check(effects.get_sheet(HitEffects.CAST, damage_type) != null, "%s cast flash" % HitEffects.ELEMENT_NAMES[damage_type])
	effects.free()
