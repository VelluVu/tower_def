class_name Beam
extends Skill

#how far the beam jumps from one enemy to the next, 2.5 tiles
const CHAIN_RANGE : float = 40.0
#a chained enemy takes this share of the beam's hit
const CHAIN_DAMAGE_SHARE : float = 0.5
#line hits (the LineHits stat): enemies this close to the beam take this share of it
const LINE_WIDTH : float = 7.0
const LINE_DAMAGE_SHARE : float = 0.6


@onready var line : Line2D = $Line2D :
	get: 
		if line == null:
			for child in get_children():
				if child is Line2D:
					line = child
		return line
		
@onready var damage_timer : CustomTimer = $DamageTimer

@export var end_line_index : int = 1
@export var tick_speed : float = 1.0
@export var beam_texture : CompressedTexture2D :
	set = _set_beam_texture
		

var is_active : bool :
	set = _set_is_active
#enemies the beam jumps on to from its target (the ChainTargets stat), in chain order
var chained_targets : Array[Enemy] = []
var position_update_timer : float = 0.0
var position_update_interval : float = 0.25


func _ready() -> void:
	line.texture = beam_texture
	damage_timer.unscaled_base_value = tick_speed
	damage_timer.timeout.connect(_on_timer_tick)
	super()


func _process(delta: float) -> void:
	if not is_active:
		return
		
	position_update_timer += delta * current_time_scale
	
	if position_update_timer > position_update_interval:
		position_update_timer = 0
		
		if not is_valid_target:
			is_active = false
			return
		
		_update_chain()


func activate() -> void:
	super()

	#the target can die or leave during the cast
	if not is_valid_target:
		stop()
		return

	is_active = true


func stop() -> void:
	super()
	is_active = false


func _on_skill_stat_changed(stat : Stat) -> void:
	super(stat)
	
	if stat.type == Utils.StatType.AttackSpeed:
		damage_timer.scale_wait_time(stat.value)


func _on_actor_stat_changed(stat : Stat) -> void:
	super(stat)
	
	if stat.type == Utils.StatType.AttackSpeed:
		damage_timer.scale_wait_time(stats.get_stat_value(Utils.StatType.AttackSpeed))


func _on_timer_tick() -> void:
	if not is_valid_target:
		is_active = false
		return
	
	_update_chain()
	_hit_target()


#damage_data is a new copy per call, nothing keeps it after the hit
func _hit_target() -> void:
	var hit : DamageData = damage_data
	target.take_damage(hit)
	hit.queue_free()

	if actor.stats.get_stat_value(Utils.StatType.LineHits) >= 1.0:
		_hit_line()

	for enemy in chained_targets:
		if not EnemyQuery.is_hittable(enemy):
			continue
		var chain_hit : DamageData = damage_data
		chain_hit.damage *= CHAIN_DAMAGE_SHARE
		enemy.take_damage(chain_hit)
		chain_hit.queue_free()


#every enemy close to the beam between the tower and its target (not the target or the chained ones)
func _hit_line() -> void:
	var from : Vector2 = actor.global_position
	var to : Vector2 = target.body_center
	for enemy in actor.level.existing_enemies.duplicate():
		if enemy == target or chained_targets.has(enemy) or not EnemyQuery.is_hittable(enemy):
			continue
		var closest : Vector2 = Geometry2D.get_closest_point_to_segment(enemy.body_center, from, to)
		if closest.distance_to(enemy.body_center) > LINE_WIDTH:
			continue
		var line_hit : DamageData = damage_data
		line_hit.damage *= LINE_DAMAGE_SHARE
		enemy.take_damage(line_hit)
		line_hit.queue_free()


## Picks the chained enemies again (each jumps from the one before) and draws the beam through them.
func _update_chain() -> void:
	chained_targets.clear()
	var chain_count : int = roundi(actor.stats.get_stat_value(Utils.StatType.ChainTargets))
	var exclude : Array = [target]
	var from : Vector2 = target.body_center

	for i in chain_count:
		var next : Enemy = EnemyQuery.closest_enemy(get_tree(), from, CHAIN_RANGE, exclude)
		if next == null:
			break
		chained_targets.append(next)
		exclude.append(next)
		from = next.body_center

	_set_line_point_count(end_line_index + 1 + chained_targets.size())
	line.set_point_position(end_line_index, target.body_center - global_position)
	for i in chained_targets.size():
		line.set_point_position(end_line_index + 1 + i, chained_targets[i].body_center - global_position)


func _set_line_point_count(point_count : int) -> void:
	while line.get_point_count() > point_count:
		line.remove_point(line.get_point_count() - 1)
	while line.get_point_count() < point_count:
		line.add_point(Vector2.ZERO)


func _set_is_active(value : bool) -> void:
	if value == is_active:
		return
	
	is_active = value
	
	if is_active:
		actor.animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION)
		_update_chain()
		_hit_target()
		damage_timer.start()
	else:
		chained_targets.clear()
		_set_line_point_count(end_line_index + 1)
		line.set_point_position(1, Vector2.ZERO)
		damage_timer.stop()
		actor.animation_control.play_animation(GlobalAnimationNames.STOP_ATTACK_ANIMATION)
		is_ready = true


func _set_beam_texture(new_texture : CompressedTexture2D) -> void:
	if new_texture == beam_texture:
		return
		
	beam_texture = new_texture
	
	if line == null:
		return

	line.texture = beam_texture


#damage ticks per second, independent of game speed
func _get_attack_speed() -> float:
	return 1.0 / damage_timer.base_wait_time if damage_timer.base_wait_time > 0.0 else 0.0
