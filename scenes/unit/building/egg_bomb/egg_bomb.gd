class_name EggBomb
extends Trap

## The Egg Bomb (2026-11-25, design doc New Towers): a trap on the path. The first ground enemy on it lights the fuse
## (its EggBlast's cast); then one big blast hits every enemy within its blast radius, flyers above it too, from the
## full hit at the centre down to MortarShell.MIN_EDGE_SHARE at the edge. The enemy nearest the egg takes the direct hit
## (element effects, crits and the tiers' TowerHitEffects once), the rest splash. Then it rebuilds itself over its
## cooldown: the scorched scrape, the shell growing back (REBUILD, its frame set by how far the rebuild has come).

const BLAST_RADIUS_TILES : float = 1.25
const REBUILD_ANIMATION : StringName = &"REBUILD"

## The blast's sprites by element: Physical (also before an element is chosen), Fire, Frost, Poison.
@export var blast_frames : Array[SpriteFrames] = []

@onready var blast_sprite : AnimatedSprite2D = $Blast

var is_rebuilding : bool = false


func _ready() -> void:
	super()
	blast_sprite.hide()
	blast_sprite.animation_finished.connect(blast_sprite.hide)
	skill.is_ready_signal.connect(_on_rebuilt)
	GameSignals.time_scale_change.connect(func(time_scale : float) -> void: blast_sprite.speed_scale = time_scale)


## The blast's reach in pixels: BLAST_RADIUS_TILES plus its SplashRadius (tiers, talents).
func get_blast_radius() -> float:
	return (BLAST_RADIUS_TILES + stats.get_stat_value(Utils.StatType.SplashRadius)) * Utils.TILE_SIZE


## Every living enemy within the blast, flyers too, nearest first; burrowed ones are under it.
func get_victims() -> Array[Enemy]:
	var victims : Array[Enemy] = []
	if level == null:
		return victims
	var blast_radius : float = get_blast_radius()
	for enemy in level.existing_enemies:
		if EnemyQuery.is_hittable(enemy) and not enemy.ignores_traps and enemy.global_position.distance_to(global_position) <= blast_radius:
			victims.append(enemy)
	victims.sort_custom(func(a : Enemy, b : Enemy) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	return victims


## The blast (EggBlast.activate): hits everything in reach with falloff, then starts the rebuild.
func detonate() -> void:
	var hit : DamageData = skill.damage_data
	var blast_radius : float = get_blast_radius()
	var victims : Array[Enemy] = get_victims()
	for i in victims.size():
		var enemy : Enemy = victims[i]
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var share : float = MortarShell.get_falloff_share(enemy.global_position.distance_to(global_position), blast_radius, MortarShell.get_area_tiles(self))
		#Pinned target: a harpooned enemy takes the full hit
		if level.synergies != null:
			share = level.synergies.get_blast_share(enemy, share)
		var copy : DamageData = MortarShell.copy_hit(hit, share)
		copy.is_splash = i > 0
		enemy.take_damage(copy)
		copy.free()
	hit.queue_free()
	targets.clear()
	_show_blast()
	#Shrapnel bed: the blast fires the Spike Fields beside it
	if level.synergies != null:
		level.synergies.on_egg_blast(self)
	is_rebuilding = true
	animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION)


func _show_blast() -> void:
	var frames : SpriteFrames = _get_blast_frames()
	if frames == null:
		return
	blast_sprite.sprite_frames = frames
	blast_sprite.show()
	blast_sprite.frame = 0
	blast_sprite.play(frames.get_animation_names()[0])


func _get_blast_frames() -> SpriteFrames:
	if blast_frames.is_empty():
		return null
	var element : Utils.Element = evolve_tree.evolve_element if evolve_tree != null and evolve_tree.is_element_chosen else Utils.Element.Physical
	var slot : int = {Utils.Element.Fire: 1, Utils.Element.Frost: 2, Utils.Element.Poison: 3}.get(element, 0)
	return blast_frames[mini(slot, blast_frames.size() - 1)]


## How far the rebuild has come, 0 right after the blast to 1 when the egg is whole.
func get_rebuild_progress() -> float:
	if not is_rebuilding:
		return 1.0
	var timer : CustomTimer = skill.cooldown_timer
	if timer.wait_time <= 0.0 or timer.is_stopped():
		return 1.0
	return clampf(1.0 - timer.time_left / timer.wait_time, 0.0, 1.0)


#an element swap brings a new sprite whose animation_finished nothing listens to, so the burst's end is watched here
func _process(_delta : float) -> void:
	if not is_rebuilding:
		return
	var frames : SpriteFrames = animation_control.sprite_frames
	if animation_control.animation == GlobalAnimationNames.ATTACK_ANIMATION and not animation_control.is_playing() 			and frames.has_animation(REBUILD_ANIMATION):
		animation_control.play(REBUILD_ANIMATION)
		animation_control.pause()
	if animation_control.animation == REBUILD_ANIMATION:
		var count : int = frames.get_frame_count(REBUILD_ANIMATION)
		animation_control.frame = mini(int(get_rebuild_progress() * count), count - 1)


func _on_rebuilt(is_ready : bool) -> void:
	if not is_ready or not is_rebuilding:
		return
	is_rebuilding = false
	#the trap may have lit the fuse again at once (an enemy already on it): that animation stays
	if animation_control.animation == REBUILD_ANIMATION and animation_control.sprite_frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION):
		animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)
