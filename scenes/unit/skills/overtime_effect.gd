class_name OvertimeEffect
extends Node


@onready var tick_timer : CustomTimer = $TickTimer

var is_finished : bool = false
var is_shielding : bool = false
var is_healing : bool = false
var tick_count : int = 0
#ticks before the effect ends, 0 = never (regeneration)
var max_count : int = 0
var tick_damage : float = 0.0
var potency : float = 0.0
#the tick interval before Thermal Shock speeds it up
var base_interval : float = 1.0
var actor : Node = null
var source : Node = null
var damage_type : Utils.DamageType = Utils.DamageType.Physical
var effect_type : Utils.OvertimeEffectType = Utils.OvertimeEffectType.Tick
var added_modifier_datas : Array[ModifierData]

#for pool
signal damage_overtime_finished(overtime_effect : OvertimeEffect)


func start(overtime_effect_data : OvertimeEffectData, _actor : Node, _tick_damage : float) -> void:
	#the data belongs to the hit's DamageData copy, which is freed after the hit: copy what is needed
	actor = _actor
	is_shielding = overtime_effect_data.is_shielding
	is_healing = overtime_effect_data.is_healing
	source = overtime_effect_data.source
	tick_damage = _tick_damage
	damage_type = overtime_effect_data.damage_type
	potency = overtime_effect_data.potency
	max_count = overtime_effect_data.get_tick_count()
	effect_type = overtime_effect_data.effectType
	base_interval = overtime_effect_data.get_tick_interval()
	tick_timer.base_wait_time = base_interval
	tick_count = 0
	is_finished = false
	
	if overtime_effect_data.is_critical:
		add_extra_effects(overtime_effect_data)
	add_extra_effects(overtime_effect_data)
	
	tick_timer.start()

	if not tick_timer.timeout.is_connected(_on_damage_tick):
		tick_timer.timeout.connect(_on_damage_tick)


func stop() -> void:
	if is_finished:
		return
	
	tick_timer.stop()
	is_finished = true
	remove_extra_effects()
	damage_overtime_finished.emit(self)


## Strength for the stack cap: -1 weaker, 0 as strong, 1 stronger than the other. Tick damage
## decides; on equal damage (slows) potency does.
func compare_strength(other_tick_damage : float, other_potency : float) -> int:
	if not is_equal_approx(tick_damage, other_tick_damage):
		return -1 if tick_damage < other_tick_damage else 1
	
	if not is_equal_approx(potency, other_potency):
		return -1 if potency < other_potency else 1
	
	return 0


## factor 1.5 = ticks 50% faster, from the next tick on.
func set_tick_speed(factor : float) -> void:
	tick_timer.base_wait_time = base_interval / factor


#each stack gets its own copy scaled by the potency of the hit that added it (slows)
func add_extra_effects(stack_data : OvertimeEffectData) -> void:
	for modifier in stack_data.modifier_datas:
		var scaled_modifier : ModifierData = modifier.scaled(1.0 + stack_data.potency)
		actor.modifier_manager.add_modifier(scaled_modifier)
		added_modifier_datas.append(scaled_modifier)


func remove_extra_effects() -> void:
	if not added_modifier_datas.is_empty():
		for modifier in added_modifier_datas:
			actor.modifier_manager.remove_modifier(modifier)
	
	added_modifier_datas.clear()


func _on_damage_tick() -> void:
	if actor.is_dead:
		stop()
		return
	
	var tick_hit : DamageData = _create_damage_data()
	tick_count += 1
	
	if max_count > 0 and tick_count >= max_count:
		stop()
	
	#a slow stack has no damage; skip the empty hit
	if not is_zero_approx(tick_hit.damage):
		actor.take_damage(tick_hit)
	tick_hit.queue_free()


func _create_damage_data() -> DamageData:
	var damage_data : DamageData = DamageData.new()
	
	if source != null:
		damage_data.source = source
	
	damage_data.is_overtime = true
	damage_data.damage = tick_damage
	damage_data.damage_type = damage_type
	damage_data.is_shielding = is_shielding
	
	return damage_data
