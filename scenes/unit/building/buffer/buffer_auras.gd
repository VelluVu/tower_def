class_name BufferAuras
extends Node

## Made by Level. Since 2026-11-26 a Buffer throws its buffs (Buffer.throw_buff -> throw_from): a building holds a
## Buffer's values for BUFF_SECONDS after a throw from it, and only the Buffers whose throw still holds count for it.
## Gives every tower and trap a Buffer's throw holds that Buffer's tracks: one modifier per stat, the
## strongest Buffer's value (several Buffers never stack). Also the element a Buffer passes on (a chance on a direct
## hit to add its element's stack; Physical: resistance penetration), the T2 weakening of enemies in the aura and the
## T3 Commander's Roar. Recomputed whenever a building comes, goes or a Buffer changes.

## The element stacks a Buffer passes on: the Bolter's element hits (burn, slow, poison stacks).
const PASS_ON_DATA : Dictionary[Utils.Element, PackedScene] = {
	Utils.Element.Fire: preload("res://scenes/unit/evolve_tree/puffe_bolter_evolve/red_puffe_bolter_evolve_damage_data.tscn"),
	Utils.Element.Frost: preload("res://scenes/unit/evolve_tree/puffe_bolter_evolve/blue_puffe_bolter_evolve_damage_data.tscn"),
	Utils.Element.Poison: preload("res://scenes/unit/evolve_tree/puffe_bolter_evolve/green_puffe_bolter_evolve_damage_data.tscn"),
}
const ELEMENT_DAMAGE : Dictionary[Utils.Element, Utils.DamageType] = {
	Utils.Element.Fire: Utils.DamageType.Fire,
	Utils.Element.Frost: Utils.DamageType.Frost,
	Utils.Element.Poison: Utils.DamageType.Poison,
}

var level : Level :
	get:
		if level == null:
			level = get_parent()
		return level

#the placed Buffers, refreshed with the auras
var buffers : Array[Buffer] = []
#building instance id -> {"building": the building (untyped: it may be freed), "mods": {StatType: ModifierData}}
var applied : Dictionary = {}
#building instance id -> {Utils.Element: chance} for the elements its hits carry
var pass_on : Dictionary = {}
var is_refresh_queued : bool = false
var roar_timer : CustomTimer = null
var roar_end_timer : CustomTimer = null
var is_roaring : bool = false
#building instance id -> {buffer instance id: seconds its last throw still holds}
var held : Dictionary = {}


func _ready() -> void:
	GameSignals.building_placed.connect(_on_building_changed)
	GameSignals.sell_building.connect(_on_building_removed)
	GameSignals.building_destroyed.connect(_on_building_removed)
	roar_timer = CustomTimer.new()
	add_child(roar_timer)
	roar_timer.unscaled_base_value = Buffer.ROAR_INTERVAL
	roar_timer.timeout.connect(_on_roar)
	roar_end_timer = CustomTimer.new()
	roar_end_timer.one_shot = true
	add_child(roar_end_timer)
	roar_end_timer.unscaled_base_value = Buffer.ROAR_SECONDS
	roar_end_timer.timeout.connect(_on_roar_end)


func _process(delta : float) -> void:
	if held.is_empty():
		return
	var step : float = delta * (Utils.game_control.time_scale if Utils.game_control != null else 1.0)
	var expired : bool = false
	for building_id in held.keys():
		var holds : Dictionary = held[building_id]
		for buffer_id in holds.keys():
			holds[buffer_id] -= step
			if holds[buffer_id] <= 0.0:
				holds.erase(buffer_id)
				expired = true
		if holds.is_empty():
			held.erase(building_id)
	if expired:
		queue_refresh()


## A Buffer's throw: the covered building with the least time left from it gets its values for BUFF_SECONDS.
func throw_from(buffer : Buffer) -> void:
	var target : Building = null
	var least : float = INF
	for building in level.all_buildings:
		if not _can_be_buffed(building) or not buffer.covers(building.global_position):
			continue
		var left : float = get_hold(building, buffer)
		if left < least:
			least = left
			target = building
	if target == null:
		return
	held.get_or_add(target.get_instance_id(), {})[buffer.get_instance_id()] = Buffer.BUFF_SECONDS
	BufferOrb.fly(buffer, target)
	queue_refresh()


## Seconds the Buffer's last throw still holds on the building (0 when none).
func get_hold(building : Building, buffer : Buffer) -> float:
	return float(held.get(building.get_instance_id(), {}).get(buffer.get_instance_id(), 0.0))


func _holds(building : Building, buffer : Buffer) -> bool:
	return get_hold(building, buffer) > 0.0


func _on_building_changed(building : Building) -> void:
	if building is Buffer and not building.aura_changed.is_connected(queue_refresh):
		building.aura_changed.connect(queue_refresh)
	queue_refresh()


func _on_building_removed(building : Building) -> void:
	_drop(building.get_instance_id())
	#the building is still in the tree this frame: the refresh skips it by its removal
	queue_refresh()


## Recomputes the auras at the end of the frame, once however many changes came.
func queue_refresh() -> void:
	if is_refresh_queued:
		return
	is_refresh_queued = true
	refresh.call_deferred()


func refresh() -> void:
	is_refresh_queued = false
	buffers.clear()
	for building in level.all_buildings:
		if is_instance_valid(building) and building is Buffer and building.is_placed and not building.is_queued_for_deletion():
			buffers.append(building)
	_update_roar_timer()

	var seen : Dictionary = {}
	for building in level.all_buildings:
		if not _can_be_buffed(building):
			continue
		var id : int = building.get_instance_id()
		seen[id] = true
		_apply(building, _best_buffs(building))
		pass_on[id] = _best_pass_on(building)
	for id in applied.keys():
		if not seen.has(id):
			_drop(id)
	for id in pass_on.keys():
		if not seen.has(id):
			pass_on.erase(id)


func _can_be_buffed(building) -> bool:
	return is_instance_valid(building) and building.is_placed and not building.is_queued_for_deletion() \
		and not building is Buffer and not building is Wall and building.skill != null


## stat -> [modify type, value]: per track the strongest covering Buffer's buff, plus penetration and the roar.
func _best_buffs(building : Building) -> Dictionary:
	var best : Dictionary = {}
	for buffer in buffers:
		if not buffer.covers(building.global_position) or not _holds(building, buffer):
			continue
		for stat in Buffer.TRACKS:
			var value : float = buffer.get_buff(stat)
			if value > 0.0 and value > float(best.get(stat, [0, 0.0])[1]):
				best[stat] = [Buffer.PIP_VALUES[stat][0], value]
		if buffer.element == Utils.Element.Physical:
			var penetration : float = buffer.get_penetration()
			if penetration > float(best.get(Utils.StatType.ResistancePenetration, [0, 0.0])[1]):
				best[Utils.StatType.ResistancePenetration] = [Utils.ModifyType.Flat, penetration]
	if is_roaring and _is_covered_by_tier(building, 3):
		var speed : float = float(best.get(Utils.StatType.AttackSpeed, [0, 0.0])[1])
		best[Utils.StatType.AttackSpeed] = [Utils.ModifyType.Flat, speed + Buffer.ROAR_ATTACK_SPEED]
	return best


func _best_pass_on(building : Building) -> Dictionary:
	var best : Dictionary = {}
	#Harmony (synergy): a tower of the Buffer's own element gets twice its chance
	var own_element : Utils.Element = Utils.Element.None
	if building.evolve_tree != null and building.evolve_tree.is_element_chosen:
		own_element = building.evolve_tree.evolve_element
	for buffer in buffers:
		var chance : float = buffer.get_pass_chance()
		if chance > 0.0 and buffer.covers(building.global_position) and _holds(building, buffer):
			if own_element == buffer.element:
				chance = minf(chance * 2.0, 1.0)
			best[buffer.element] = maxf(chance, best.get(buffer.element, 0.0))
	return best


func _is_covered_by_tier(building : Building, min_tier : int) -> bool:
	for buffer in buffers:
		if buffer.tier >= min_tier and buffer.covers(building.global_position):
			return true
	return false


#swaps a building's aura modifiers for the new values, leaving unchanged ones alone
func _apply(building : Building, best : Dictionary) -> void:
	var id : int = building.get_instance_id()
	if not applied.has(id):
		applied[id] = {"building": building, "mods": {}}
	var mods : Dictionary = applied[id]["mods"]
	var changed : bool = false
	for stat in mods.keys():
		var old : ModifierData = mods[stat]
		if best.has(stat) and is_equal_approx(old.value, float(best[stat][1])) and old.calculate_type == best[stat][0]:
			continue
		building.modifier_manager.remove_modifier(old)
		mods.erase(stat)
		changed = true
	for stat in best:
		if mods.has(stat) or building.stats.get_stat(stat) == null:
			continue
		var data : ModifierData = ModifierData.new()
		data.modifier_type = Utils.ModifierType.StatModifier
		data.stat_type = stat
		data.calculate_type = best[stat][0]
		data.value = best[stat][1]
		building.modifier_manager.add_modifier(data)
		mods[stat] = data
		changed = true
	if changed:
		building.stats_changed.emit()


func _drop(id : int) -> void:
	if not applied.has(id):
		return
	var entry : Dictionary = applied[id]
	applied.erase(id)
	held.erase(id)
	pass_on.erase(id)
	var building = entry["building"]
	if not is_instance_valid(building):
		return
	for stat in entry["mods"]:
		building.modifier_manager.remove_modifier(entry["mods"][stat])


## Every modifier the auras put on this building right now (stat -> ModifierData), for tests and the selection card.
func get_buffs(building : Building) -> Dictionary:
	var entry : Dictionary = applied.get(building.get_instance_id(), {})
	return entry.get("mods", {})


## A buffed building's direct hit: each element passed on to it may add one stack of that element to the target.
func on_direct_hit(target : Enemy, tower : Building, raw_damage : float) -> void:
	var elements : Dictionary = pass_on.get(tower.get_instance_id(), {})
	for element in elements:
		if randf() >= float(elements[element]):
			continue
		var hit : DamageData = PASS_ON_DATA[element].instantiate()
		hit.source = tower
		for effect_data in hit.overtime_effect_datas:
			#the roll above was the chance; the hitting tower's own effect stats (potency, stacks) shape the stack
			effect_data.chance_to_apply = 1.0
			effect_data.read_source_stats(tower.stats)
		target.overtime_effect_handler.handle_overtime_effects(hit.overtime_effect_datas, raw_damage)
		hit.free()


## T2 and up: enemies inside the aura take this share more damage from buildings (the strongest Buffer counts).
func get_weakness(enemy : Enemy) -> float:
	for buffer in buffers:
		if is_instance_valid(buffer) and buffer.tier >= 2 and buffer.covers(enemy.global_position):
			return Buffer.WEAKEN_SHARE
	return 0.0


func _update_roar_timer() -> void:
	var has_roarer : bool = buffers.any(func(buffer) -> bool: return is_instance_valid(buffer) and buffer.tier >= 3)
	if has_roarer and roar_timer.is_stopped():
		roar_timer.start()
	elif not has_roarer and not roar_timer.is_stopped():
		roar_timer.stop()
		is_roaring = false


func _on_roar() -> void:
	is_roaring = true
	for buffer in buffers:
		if is_instance_valid(buffer) and buffer.tier >= 3:
			buffer.play_roar()
			#War cry (synergy): the roar readies the Elder Drakes' breath
			if level.synergies != null:
				level.synergies.on_roar(buffer)
	roar_end_timer.start()
	queue_refresh()


func _on_roar_end() -> void:
	is_roaring = false
	queue_refresh()
