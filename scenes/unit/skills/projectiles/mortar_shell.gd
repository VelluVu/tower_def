class_name MortarShell
extends Node2D

## The Mortar's shell: lobbed in an arc at the spot its target will reach, it bursts where it lands. Every ground
## enemy in the blast is hit, from the full hit at the centre down to MIN_EDGE_SHARE at the edge; the enemy nearest
## the centre takes it as a direct hit (the tower's on-hit effects: patch, knockback, split), the rest as splash.
## Flyers are above it and burrowed enemies below it. The blast radius is BLAST_RADIUS_TILES plus the tower's
## SplashRadius stat (Wide Shells, tiers). Pooled by LaunchProjectile like the bolts.

signal finished(node : Node2D)

## Seconds in the air at 1x speed.
const FLIGHT_SECONDS : float = 0.9
## How high the arc rises, in pixels, over a range-long lob; short lobs rise less.
const ARC_HEIGHT : float = 30.0
const MIN_ARC_HEIGHT : float = 12.0
const BLAST_RADIUS_TILES : float = 1.0
## The share of the hit an enemy at the blast's edge takes.
const MIN_EDGE_SHARE : float = 0.5
## The shell aims where its target will be, but never further ahead than this.
const MAX_LEAD_TILES : float = 2.0
const SHADOW_COLOR : Color = Color(0.09, 0.08, 0.15, 0.35)
## In the air over the units; the blast and shadow on the ground under them.
const FLIGHT_Z_INDEX : int = 15

@export var projectile_name : String = "MortarShell"

@onready var shell_sprite : AnimatedSprite2D = $Shell
@onready var blast_sprite : AnimatedSprite2D = $Blast

var is_old : bool = false
var skill_data : SkillData = null
var start_position : Vector2 = Vector2.ZERO
var landing_position : Vector2 = Vector2.ZERO
var arc_height : float = ARC_HEIGHT
#0 at launch, 1 on landing
var progress : float = 0.0
var is_flying : bool = false
var current_time_scale : float = 1.0


func launch(_skill_data : SkillData) -> void:
	skill_data = _skill_data
	_activate()


func clear() -> void:
	queue_free()


func _ready() -> void:
	if not GameSignals.time_scale_change.is_connected(_on_time_scale_change):
		GameSignals.time_scale_change.connect(_on_time_scale_change)
	if not blast_sprite.animation_finished.is_connected(_on_blast_finished):
		blast_sprite.animation_finished.connect(_on_blast_finished)


func _activate() -> void:
	#outside the tree (a test's stand-in Main) the shell was never readied and cannot fly
	if not is_node_ready():
		return
	_on_time_scale_change(Utils.game_control.time_scale)
	start_position = global_position
	landing_position = get_landing_position(skill_data.target, start_position)
	var reach : float = maxf(skill_data.max_range, 1.0)
	arc_height = lerpf(MIN_ARC_HEIGHT, ARC_HEIGHT, clampf(start_position.distance_to(landing_position) / reach, 0.0, 1.0))
	progress = 0.0
	is_flying = true
	z_index = FLIGHT_Z_INDEX
	show()
	shell_sprite.show()
	shell_sprite.position = Vector2.ZERO
	shell_sprite.play()
	blast_sprite.hide()
	blast_sprite.stop()
	queue_redraw()


## Where a shell fired now at target lands: its position plus its walk over the flight, at most MAX_LEAD_TILES.
static func get_landing_position(target : Node2D, from : Vector2) -> Vector2:
	if not is_instance_valid(target):
		return from
	var aim : Vector2 = target.global_position
	var enemy : Enemy = target as Enemy
	#a frozen (or parked) body stands still; its velocity is stale through turn pauses and freezes, its linear velocity not
	if enemy != null and not enemy.freeze and not enemy.is_frozen:
		var time_scale : float = maxf(Utils.game_control.time_scale, 0.01) if Utils.game_control != null else 1.0
		#the enemy's speed already carries the game speed; the flight is in game time
		var lead : Vector2 = enemy.linear_velocity / time_scale * FLIGHT_SECONDS
		aim += lead.limit_length(MAX_LEAD_TILES * Utils.TILE_SIZE)
	return aim


func _process(delta : float) -> void:
	if not is_flying:
		return
	progress = minf(progress + delta * current_time_scale / FLIGHT_SECONDS, 1.0)
	global_position = start_position.lerp(landing_position, progress)
	#a parabola: up and down again over the flight
	shell_sprite.position.y = -roundf(4.0 * arc_height * progress * (1.0 - progress))
	queue_redraw()
	if progress >= 1.0:
		_land()


func _land() -> void:
	is_flying = false
	shell_sprite.stop()
	shell_sprite.hide()
	z_index = 0
	queue_redraw()
	if skill_data != null and is_instance_valid(skill_data.damage_data):
		#a freed source cannot reach the typed calls below
		skill_data.damage_data.drop_freed_source()
		blast(skill_data.damage_data, global_position, get_blast_radius(skill_data.damage_data.source))
	blast_sprite.show()
	blast_sprite.frame = 0
	blast_sprite.speed_scale = current_time_scale
	blast_sprite.play()


## The blast's reach in pixels for a shell from tower.
static func get_blast_radius(tower : Node) -> float:
	var tiles : float = BLAST_RADIUS_TILES
	if is_instance_valid(tower) and tower is Building:
		tiles += (tower as Building).stats.get_stat_value(Utils.StatType.SplashRadius)
	return tiles * Utils.TILE_SIZE


## Hits every ground enemy within radius of at, with falloff; the nearest takes the direct hit. Returns the enemies hit.
static func blast(hit : DamageData, at : Vector2, radius : float) -> Array[Enemy]:
	hit.drop_freed_source()
	var victims : Array[Enemy] = get_blast_victims(hit.source, at, radius)
	for i in victims.size():
		var enemy : Enemy = victims[i]
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var share : float = get_falloff_share(enemy.global_position.distance_to(at), radius)
		var copy : DamageData = copy_hit(hit, share)
		copy.is_splash = i > 0
		enemy.take_damage(copy)
		copy.free()
	return victims


## Living, walking, above-ground enemies within radius of at, nearest first.
static func get_blast_victims(source : Node, at : Vector2, radius : float) -> Array[Enemy]:
	var victims : Array[Enemy] = []
	#a tower sold while its shell flew takes the blast with it
	if not is_instance_valid(source) or not source is Building or (source as Building).level == null:
		return victims
	var level : Level = (source as Building).level
	for enemy in level.existing_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.is_burrowed or enemy.is_flying:
			continue
		if enemy.global_position.distance_to(at) <= radius:
			victims.append(enemy)
	victims.sort_custom(func(a : Enemy, b : Enemy) -> bool:
		return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	return victims


## 1 at the centre down to MIN_EDGE_SHARE at the edge.
static func get_falloff_share(distance : float, radius : float) -> float:
	if radius <= 0.0:
		return 1.0
	return lerpf(1.0, MIN_EDGE_SHARE, clampf(distance / radius, 0.0, 1.0))


## A copy of the shell's hit at share of its damage, with the same crit and the tower's effect stats.
static func copy_hit(hit : DamageData, share : float) -> DamageData:
	var copy : DamageData = hit.duplicate()
	copy.is_critical = hit.is_critical
	copy.damage = hit.damage * share
	if is_instance_valid(hit.source):
		copy.source = hit.source
	for effect_data in copy.overtime_effect_datas:
		effect_data.is_critical = copy.is_critical
		if is_instance_valid(hit.source) and hit.source is Building:
			effect_data.read_source_stats((hit.source as Building).stats)
	return copy


func _on_blast_finished() -> void:
	blast_sprite.hide()
	hide()
	#the hit is used: the shell's data lets go of it
	skill_data = null
	finished.emit(self)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	if blast_sprite != null and blast_sprite.is_playing():
		blast_sprite.speed_scale = time_scale


#the shadow on the ground under the shell, smaller the higher it flies
func _draw() -> void:
	if not is_flying:
		return
	var height_share : float = clampf(-shell_sprite.position.y / maxf(arc_height, 1.0), 0.0, 1.0)
	var half_width : float = roundf(lerpf(3.0, 1.5, height_share))
	draw_rect(Rect2(-half_width, -1.0, half_width * 2.0, 2.0), SHADOW_COLOR)
