class_name Breath
extends Skill

## The Breather's attack (2026-11-24): a gust of breath that hits every enemy in a cone in front of the tower,
## GUST_TICKS times over GUST_SECONDS, then the cooldown. Only an enemy's first hit in a gust is a direct hit, so
## knockback, stuns and a Buffer's element come once per gust; a gust with PatchDuration leaves one ground patch in
## the middle of its cone. Element puffs fly out along the cone (projectile_scene, swapped by the element leaves).
## The cone follows its target while the gust lasts.

const GUST_TICKS : int = 4
const GUST_SECONDS : float = 1.0
## The cone's full width in degrees before the ConeWidth stat, and the widest it can get.
const BASE_CONE_DEGREES : float = 60.0
const MAX_CONE_DEGREES : float = 170.0
const PUFF_SECONDS : float = 0.05
const PUFF_LIFETIME : float = 0.4
const PUFF_Z_INDEX : int = 12
## The patch lands at this share of the cone's length.
const PATCH_AT : float = 0.55

@export var projectile_scene : PackedScene

#the way the cone points, from the tower
var direction : Vector2 = Vector2.RIGHT
var ticks_left : int = 0
var is_breathing : bool = false
#enemy instance id -> true: who had this gust's direct hit
var hit_this_gust : Dictionary = {}
var tick_timer : CustomTimer = null
var puff_timer : CustomTimer = null
var puff_pool : Array[BreathPuff] = []
var live_puffs : Array[BreathPuff] = []


func _ready() -> void:
	super()
	tick_timer = CustomTimer.new()
	add_child(tick_timer)
	tick_timer.unscaled_base_value = GUST_SECONDS / GUST_TICKS
	tick_timer.timeout.connect(_on_tick_timer)
	puff_timer = CustomTimer.new()
	add_child(puff_timer)
	puff_timer.unscaled_base_value = PUFF_SECONDS
	puff_timer.timeout.connect(_puff)


#a gust is not cut short by the next cast: high attack speed waits for it to end
func use(_target : Node2D) -> void:
	if is_breathing:
		return
	super(_target)


## Swaps the puffs for another element's (an element leaf); the old ones go at once, they are only for looks.
func new_projectile(new_scene : PackedScene) -> void:
	clear_all_particles()
	projectile_scene = new_scene


func activate() -> void:
	super()
	#the target can die or leave during the cast
	if not is_valid_target:
		_end_gust()
		return
	_aim()
	hit_this_gust.clear()
	ticks_left = GUST_TICKS
	is_breathing = true
	actor.animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION)
	_drop_patch()
	_tick()
	tick_timer.start()
	puff_timer.start()


func stop() -> void:
	super()
	if is_breathing:
		_end_gust()


## The cone's full width in degrees, with the ConeWidth stat.
func get_cone_degrees() -> float:
	return clampf(BASE_CONE_DEGREES + actor.stats.get_stat_value(Utils.StatType.ConeWidth), 10.0, MAX_CONE_DEGREES)


## The cone's length in pixels (its range).
func get_reach() -> float:
	return stats.get_range_in_tiles()


## True when this enemy is inside the cone and the breath can hit it. enemy untyped: a freed one must reach the
## is_instance_valid check, a typed parameter would reject it first.
func is_in_cone(enemy) -> bool:
	if not is_instance_valid(enemy) or not enemy is Enemy or not EnemyQuery.is_hittable(enemy):
		return false
	if enemy.is_flying and (enemy.is_concealed or (actor is Tower and not actor.hits_air)):
		return false
	var to : Vector2 = enemy.global_position - actor.global_position
	if to.length() > get_reach():
		return false
	#an enemy on the tower's own tile is always in it
	if to.length() < Utils.TILE_SIZE * 0.5:
		return true
	return absf(direction.angle_to(to)) <= deg_to_rad(get_cone_degrees()) * 0.5


func _aim() -> void:
	if not is_valid_target:
		return
	var to : Vector2 = target.global_position - actor.global_position
	if to.length() > 0.5:
		direction = to.normalized()


func _on_tick_timer() -> void:
	if ticks_left > 0:
		_tick()
	else:
		_end_gust()


func _tick() -> void:
	ticks_left -= 1
	_aim()
	if actor.level == null:
		return
	for enemy in actor.level.existing_enemies.duplicate():
		if not is_in_cone(enemy):
			continue
		var id : int = enemy.get_instance_id()
		var hit : DamageData = damage_data
		#the gust's later hits on the same enemy bring no knockback, stun or patch again
		hit.is_splash = hit_this_gust.has(id)
		hit_this_gust[id] = true
		enemy.take_damage(hit)
		hit.queue_free()


func _drop_patch() -> void:
	var seconds : float = actor.stats.get_stat_value(Utils.StatType.PatchDuration)
	if seconds <= 0.0 or actor.level == null:
		return
	var hit : DamageData = damage_data
	GroundPatch.make(actor.global_position + direction * get_reach() * PATCH_AT, actor, hit.damage_type, hit.damage,
		actor.stats.get_stat_value(Utils.StatType.PatchShare), seconds)
	hit.queue_free()


func _end_gust() -> void:
	is_breathing = false
	ticks_left = 0
	hit_this_gust.clear()
	if tick_timer != null:
		tick_timer.stop()
	if puff_timer != null:
		puff_timer.stop()
	actor.animation_control.play_animation(GlobalAnimationNames.STOP_ATTACK_ANIMATION, cooldown_timer.time_left, true)


#a puff flies from the mouth out along the cone and fades
func _puff() -> void:
	if projectile_scene == null or actor.level == null:
		return
	var puff : BreathPuff = _get_puff()
	var half : float = deg_to_rad(get_cone_degrees()) * 0.5
	var heading : Vector2 = direction.rotated(randf_range(-half, half))
	var speed : float = get_reach() / PUFF_LIFETIME * randf_range(0.7, 1.0)
	puff.launch(global_position, heading * speed, PUFF_LIFETIME)


func _get_puff() -> BreathPuff:
	var puff : BreathPuff = null
	if puff_pool.is_empty():
		puff = projectile_scene.instantiate()
		puff.z_index = PUFF_Z_INDEX
		puff.finished.connect(_on_puff_finished)
		actor.level.add_child(puff)
	else:
		puff = puff_pool.pop_back()
	live_puffs.append(puff)
	return puff


#a puff queued for freeing (new_projectile, a sale) can still finish this frame: it never goes back to the pool
func _on_puff_finished(puff : BreathPuff) -> void:
	live_puffs.erase(puff)
	if not puff.is_queued_for_deletion():
		puff_pool.append(puff)


func _exit_tree() -> void:
	clear_all_particles()


func clear_all_particles() -> void:
	for puff in live_puffs + puff_pool:
		if is_instance_valid(puff):
			puff.finished.disconnect(_on_puff_finished)
			puff.queue_free()
	live_puffs.clear()
	puff_pool.clear()


#hits per second on one enemy in the cone, independent of game speed
func _get_attack_speed() -> float:
	var attack_time : float = cast_timer.base_wait_time + cooldown_timer.base_wait_time
	return GUST_TICKS / attack_time if attack_time > 0.0 else 0.0
