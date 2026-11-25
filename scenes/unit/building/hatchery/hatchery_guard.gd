class_name HatcheryGuard
extends StaticBody2D

## A Hatchery's guard drakeling (2026-11-25, design doc New Towers): it hatches at the nest, walks to its post by the
## Hatchery's rally cell and holds the first ground enemy that comes near: that enemy stops (Enemy.held_by) and fights
## back with its own attack, which lands on this body (the building physics layer, so MeleeAttack's area finds it).
## The guard claws it with the Hatchery's damage data, so the Hatchery's element, crits, cards and tier effects all
## count. A boss is never stopped, only slowed while guards claw at it; flyers pass over. A fallen guard hatches
## again after Hatchery.RESPAWN_SECONDS. Owned and positioned by its Hatchery (top_level, a child of it).

enum State { WAITING, HATCHING, ACTIVE, DYING }

## Pixels a second it walks; a little faster to catch an enemy it engages.
const WALK_SPEED : float = 26.0
const RUN_SPEED : float = 40.0
## An enemy this close to its post (tiles) is engaged; one dragged farther than LEASH_TILES from it is let go.
const ENGAGE_TILES : float = 0.9
const LEASH_TILES : float = 1.75
## Pixels it stands from the enemy it holds, and how close it must be to claw.
const STAND_OFF : float = 8.0
const CLAW_REACH : float = 11.0
## The slow on a boss while this guard claws at it (one per guard, so three guards slow it about 40%).
const BOSS_SLOW : float = 0.15
## A post this close (pixels) counts as reached.
const ARRIVE_DISTANCE : float = 1.0
const HATCH_ANIMATION : StringName = &"HATCH"
const HEALTH_BAR_WIDTH : float = 10.0
const HEALTH_BAR_Y : float = -16.0
const HEALTH_BAR_BACK : Color = Color("181425")
const HEALTH_BAR_FILL : Color = Color("63c74d")
const HEALTH_BAR_LOW : Color = Color("e43b44")

@onready var animation_control : AnimationControl = $AnimatedSprite2D
@onready var collision_shape : CollisionShape2D = $CollisionShape2D

var hatchery : Hatchery = null
## Which guard of its Hatchery it is: its post's offset around the rally cell.
var index : int = 0
var state : State = State.WAITING
var health : float = 0.0
var max_health : float = 1.0
#the enemy it holds or claws at; untyped so a freed one reaches the is_instance_valid checks
var enemy = null
var boss_slow : ModifierData = null
var wait_left : float = 0.0
var attack_left : float = 0.0
var current_time_scale : float = 1.0
#its exact position; the body itself sits on whole pixels
var exact_position : Vector2 = Vector2.ZERO

## Enemies stop attacking a fallen or unhatched guard (Skill._is_target_valid).
var is_dead : bool :
	get:
		return state != State.ACTIVE

var is_holding : bool :
	get:
		return is_instance_valid(enemy)


func _ready() -> void:
	top_level = true
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	if Utils.game_control != null:
		_on_time_scale_change(Utils.game_control.time_scale)
	animation_control.animation_finished.connect(_on_animation_finished)
	_set_present(false)


## Starts its hatch after seconds (0: at once), at the nest.
func hatch_after(seconds : float) -> void:
	_release()
	state = State.WAITING
	wait_left = seconds
	_set_present(false)


func set_frames(frames : SpriteFrames) -> void:
	if frames == null or animation_control.sprite_frames == frames:
		return
	var current : StringName = animation_control.animation
	animation_control.sprite_frames = frames
	if frames.has_animation(current):
		animation_control.play(current)


## Its max health from the Hatchery: a raise heals by the difference, a cut keeps it at most the new max.
func set_max_health(value : float) -> void:
	value = maxf(value, 1.0)
	if state == State.ACTIVE:
		health = clampf(health + value - max_health, 1.0, value)
	max_health = value
	queue_redraw()


## Its post: around the rally cell, a few pixels apart from the other guards.
func get_post() -> Vector2:
	if hatchery == null:
		return global_position
	return hatchery.get_post(index)


func take_damage(damage_data : DamageData) -> void:
	if state != State.ACTIVE:
		return
	damage_data.drop_freed_source()
	health -= damage_data.damage
	GameSignals.damage_taken.emit(global_position + Vector2(0.0, HEALTH_BAR_Y), damage_data)
	if damage_data.damage > 0.0:
		animation_control.play_hit_animation()
		if damage_data.source != null:
			damage_data.source.dealt_damage(self, damage_data)
	queue_redraw()
	if health <= 0.0:
		_die()


#an enemy's hit report back to its attacker; nothing to do here
func dealt_damage(_target : Node2D, _damage_data : DamageData) -> void:
	pass


func _physics_process(delta : float) -> void:
	var game_delta : float = delta * current_time_scale
	match state:
		State.WAITING:
			wait_left -= game_delta
			if wait_left <= 0.0:
				_start_hatch()
		State.ACTIVE:
			_act(game_delta)


func _start_hatch() -> void:
	if hatchery == null:
		return
	state = State.HATCHING
	health = max_health
	_place_at(hatchery.get_nest_position(index))
	_set_present(true)
	collision_shape.set_deferred("disabled", true)
	animation_control.play_animation(HATCH_ANIMATION)
	hatchery.play_hatch()


func _act(game_delta : float) -> void:
	if is_holding and not _can_keep(enemy):
		_release()
	if not is_holding:
		_engage(_find_enemy())

	var post : Vector2 = get_post()
	if not is_holding:
		_walk_to(post, WALK_SPEED, game_delta)
		return

	#stand beside the enemy, on the post's side of it, and claw when close
	var side : float = 1.0 if post.x >= enemy.global_position.x else -1.0
	var spot : Vector2 = enemy.global_position + Vector2(STAND_OFF * side, 0.0)
	var is_moving : bool = _walk_to(spot, RUN_SPEED, game_delta)
	animation_control.flip_h = enemy.global_position.x < global_position.x
	attack_left -= game_delta
	if attack_left <= 0.0 and global_position.distance_to(enemy.global_position) <= CLAW_REACH:
		_claw()
	elif not is_moving and animation_control.animation != GlobalAnimationNames.ATTACK_ANIMATION:
		animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)


## Moves toward to; true while it still has a way to go.
func _walk_to(to : Vector2, speed : float, game_delta : float) -> bool:
	var distance : float = exact_position.distance_to(to)
	if distance <= ARRIVE_DISTANCE:
		if not is_holding:
			animation_control.flip_h = false
			if animation_control.animation != GlobalAnimationNames.ATTACK_ANIMATION:
				animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)
		return false
	var step : float = minf(speed * game_delta, distance)
	var direction : Vector2 = exact_position.direction_to(to)
	_place_at(exact_position + direction * step)
	if not is_holding:
		animation_control.flip_h = direction.x < 0.0
	if animation_control.animation != GlobalAnimationNames.ATTACK_ANIMATION:
		animation_control.play_animation(GlobalAnimationNames.WALK_ANIMATION)
	return true


func _claw() -> void:
	attack_left = hatchery.get_attack_seconds()
	animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION)
	var hit : DamageData = hatchery.skill.damage_data
	enemy.take_damage(hit)
	hit.queue_free()


## The nearest enemy near its post it may take: a ground one no other guard holds, or a boss (several may claw at one).
func _find_enemy() -> Enemy:
	if hatchery == null or hatchery.level == null:
		return null
	var post : Vector2 = get_post()
	var best : Enemy = null
	var best_distance : float = ENGAGE_TILES * Utils.TILE_SIZE
	for candidate in hatchery.level.existing_enemies:
		if not _can_take(candidate):
			continue
		var distance : float = candidate.global_position.distance_to(post)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


## candidate untyped: a freed enemy in the level's list must reach the is_instance_valid check.
func _can_take(candidate) -> bool:
	if not is_instance_valid(candidate) or not candidate is Enemy or not EnemyQuery.is_hittable(candidate):
		return false
	if candidate.is_flying or candidate.is_wading or not candidate.can_be_held:
		return false
	return candidate.is_boss or not is_instance_valid(candidate.held_by)


func _can_keep(held) -> bool:
	if not is_instance_valid(held) or not EnemyQuery.is_hittable(held) or held.is_flying or held.is_wading:
		return false
	return held.global_position.distance_to(get_post()) <= LEASH_TILES * Utils.TILE_SIZE


func _engage(target : Enemy) -> void:
	if target == null:
		return
	enemy = target
	attack_left = 0.0
	if target.is_boss:
		boss_slow = ModifierData.new()
		boss_slow.stat_type = Utils.StatType.Speed
		boss_slow.calculate_type = Utils.ModifyType.Multiply
		boss_slow.value = -BOSS_SLOW
		target.modifier_manager.add_modifier(boss_slow)
	else:
		target.held_by = self
		target.linear_velocity = Vector2.ZERO


func _release() -> void:
	if is_instance_valid(enemy):
		if enemy.held_by == self:
			enemy.held_by = null
		if boss_slow != null:
			enemy.modifier_manager.remove_modifier(boss_slow)
	boss_slow = null
	enemy = null


func _die() -> void:
	_release()
	state = State.DYING
	collision_shape.set_deferred("disabled", true)
	animation_control.play_animation(GlobalAnimationNames.DEATH_ANIMATION)
	queue_redraw()


func _on_animation_finished() -> void:
	match state:
		State.HATCHING:
			state = State.ACTIVE
			collision_shape.set_deferred("disabled", false)
			animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)
			queue_redraw()
		State.DYING:
			hatch_after(Hatchery.RESPAWN_SECONDS if hatchery == null else hatchery.get_respawn_seconds())
		_:
			if animation_control.animation == GlobalAnimationNames.ATTACK_ANIMATION:
				animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)


func _place_at(world_position : Vector2) -> void:
	exact_position = world_position
	global_position = world_position.round()


func _set_present(value : bool) -> void:
	visible = value
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not value)


#a small health bar over a hurt guard
func _draw() -> void:
	if state != State.ACTIVE or health >= max_health:
		return
	var share : float = clampf(health / max_health, 0.0, 1.0)
	var left : float = -HEALTH_BAR_WIDTH * 0.5
	draw_rect(Rect2(left - 1.0, HEALTH_BAR_Y - 1.0, HEALTH_BAR_WIDTH + 2.0, 3.0), HEALTH_BAR_BACK)
	draw_rect(Rect2(left, HEALTH_BAR_Y, roundf(HEALTH_BAR_WIDTH * share), 1.0), HEALTH_BAR_FILL if share > 0.35 else HEALTH_BAR_LOW)


func _exit_tree() -> void:
	_release()


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
