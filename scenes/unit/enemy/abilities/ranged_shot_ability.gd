class_name RangedShotAbility
extends EnemyAbility

## Stops, plays the attack and fires an EnemyShot at a building in range: the archer's arrow, the wizard's
## spell, the destroyerling's rock, the Bog Hydra's acid. The shot hits where the building stood; with an area it hits every
## building there. Walks on while the shot flies.

enum TargetRule {Nearest, Farthest}

const NO_TEXTURE_WARNING : String = " has a ranged shot without a texture"
## How near the bolt's line a building must stand to be hit, in pixels.
const PIERCE_HALF_WIDTH : float = 6.0

## In tiles from the enemy to the building.
@export var shot_range : float = 4.0
@export var target_rule : TargetRule = TargetRule.Nearest
## Towers only (spells, rocks); otherwise walls too (traps never, enemies walk over them).
@export var towers_only : bool = false
@export var damage : float = 1.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Physical
## In tiles; 0 = only the target.
@export var area_radius : float = 0.0
@export var shot_animation : String = GlobalAnimationNames.ATTACK_ANIMATION
## The rusted ballista's bolt: it goes on through the target and hits every building on its line, shot_range long.
@export var pierce_line : bool = false
## The lava spitter's glob: the cells it lands on (area_radius) cannot be built on for this long (Scorch); 0 = none.
@export var scorch_seconds : float = 0.0

@export_group("Shot")
@export var shot_texture : Texture2D = null
@export var shot_hframes : int = 1
@export var shot_vframes : int = 1
@export var shot_speed : float = 140.0
@export var shot_arc : float = 0.0
@export var shot_rotates : bool = false
## Where the shot leaves the enemy, from its origin (its feet).
@export var shot_offset : Vector2 = Vector2(0, -8)

var target : Building = null


func _can_use() -> bool:
	target = _pick_target()
	return target != null


func _run() -> void:
	enemy.animation_control.flip(target.global_position - enemy.global_position)
	if not await _play_and_wait(shot_animation):
		return

	_fire()
	_finish()


func _pick_target() -> Building:
	if enemy == null or enemy.level == null:
		return null

	var reach : float = shot_range * Utils.TILE_SIZE
	var best : Building = null
	var best_distance : float = 0.0

	for building in enemy.level.all_buildings:
		if not is_instance_valid(building) or building.is_dead or not building.is_placed or building is Trap:
			continue
		if towers_only and not building is Tower:
			continue

		var distance : float = building.global_position.distance_to(enemy.global_position)
		if distance > reach:
			continue
		if best == null or (distance < best_distance if target_rule == TargetRule.Nearest else distance > best_distance):
			best = building
			best_distance = distance

	return best


## What a landing does, kept apart from the shooter: it can die or leak (and be freed) while its shot flies.
class ShotHit:
	extends RefCounted
	var damage : float = 0.0
	var damage_type : Utils.DamageType = Utils.DamageType.Physical
	## In tiles; 0 = only the target.
	var area_radius : float = 0.0
	## The bolt's start; with pierce_length it hits every building on the line from there through the target.
	var from : Vector2 = Vector2.ZERO
	## In pixels; 0 = no piercing.
	var pierce_length : float = 0.0
	var scorch_seconds : float = 0.0


func _make_hit() -> ShotHit:
	var hit : ShotHit = ShotHit.new()
	hit.damage = damage
	hit.damage_type = damage_type
	hit.area_radius = area_radius
	hit.from = enemy.global_position
	hit.pierce_length = shot_range * Utils.TILE_SIZE if pierce_line else 0.0
	hit.scorch_seconds = scorch_seconds
	return hit


func _fire() -> void:
	var aim : Vector2 = target.global_position if is_instance_valid(target) else enemy.global_position
	if shot_texture == null:
		push_warning(enemy.name, NO_TEXTURE_WARNING)
		_land(aim, weakref(target), weakref(enemy.level), _make_hit())
		return

	var shot : EnemyShot = EnemyShot.new()
	shot.setup(shot_texture, shot_hframes, shot_vframes, enemy.global_position + shot_offset, aim)
	shot.speed = shot_speed
	shot.arc_height = shot_arc
	shot.rotates = shot_rotates
	#the target can be sold meanwhile too: the landing is static and holds only weak references
	shot.landed.connect(RangedShotAbility._land.bind(aim, weakref(target), weakref(enemy.level), _make_hit()).unbind(1))
	enemy.level.add_child(shot)


static func _land(at : Vector2, target_ref : WeakRef, level_ref : WeakRef, shot_hit : ShotHit) -> void:
	var level : Level = level_ref.get_ref() as Level
	if level == null:
		return

	var aimed_at : Building = target_ref.get_ref() as Building
	var hit : Array[Building] = []
	if shot_hit.pierce_length > 0.0:
		var end : Vector2 = shot_hit.from + (at - shot_hit.from).normalized() * shot_hit.pierce_length
		for building in level.all_buildings:
			if is_instance_valid(building) and not building.is_dead and not building is Trap \
					and Geometry2D.get_closest_point_to_segment(building.global_position, shot_hit.from, end).distance_to(building.global_position) <= PIERCE_HALF_WIDTH:
				hit.append(building)
	elif shot_hit.area_radius > 0.0:
		var reach : float = shot_hit.area_radius * Utils.TILE_SIZE
		for building in level.all_buildings:
			if is_instance_valid(building) and not building.is_dead and not building is Trap and building.global_position.distance_to(at) <= reach:
				hit.append(building)
	elif aimed_at != null and not aimed_at.is_dead:
		hit.append(aimed_at)

	for building in hit:
		var damage_data : DamageData = DamageData.new()
		damage_data.damage_type = shot_hit.damage_type
		damage_data.damage = shot_hit.damage
		building.take_damage(damage_data)
		damage_data.free()
	#the lava spitter's shot: no building on those cells for a while
	if shot_hit.scorch_seconds > 0.0:
		Scorch.make(level, at, shot_hit.area_radius, shot_hit.scorch_seconds)
