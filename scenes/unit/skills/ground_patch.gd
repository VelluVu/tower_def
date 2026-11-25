class_name GroundPatch
extends Node2D

## A patch a tower's hit leaves on the ground (burning ground, chilled ground, a poison cloud): for a few seconds
## every walking enemy inside takes a share of the hit each half second, in the hit's element. Made by
## TowerHitEffects from the tower's PatchDuration and PatchShare stats.

const TICK_SECONDS : float = 0.5
const RADIUS_TILES : float = 0.75
const COLORS : Dictionary[Utils.DamageType, Color] = {
	Utils.DamageType.Physical: Color(0.55, 0.6, 0.7, 0.35),
	Utils.DamageType.Fire: Color(0.97, 0.46, 0.13, 0.35),
	Utils.DamageType.Frost: Color(0.17, 0.91, 0.96, 0.3),
	Utils.DamageType.Poison: Color(0.48, 0.75, 0.29, 0.35),
}

var tower : Building = null
var damage_type : Utils.DamageType = Utils.DamageType.Physical
var tick_damage : float = 0.0
var ticks_left : int = 0
var tick_timer : CustomTimer = null


static func make(at : Vector2, source : Building, element : Utils.DamageType, hit_damage : float, share : float, seconds : float) -> GroundPatch:
	var patch : GroundPatch = GroundPatch.new()
	patch.tower = source
	patch.damage_type = element
	#the share is per second, the patch ticks twice as often
	patch.tick_damage = hit_damage * share * TICK_SECONDS
	patch.ticks_left = maxi(roundi(seconds / TICK_SECONDS), 1)
	patch.z_index = -1
	source.level.add_child(patch)
	patch.global_position = at
	#Ground reactions: a patch meeting another of a partner element
	if source.level.synergies != null:
		source.level.synergies.on_patch(patch)
	return patch


func _ready() -> void:
	add_to_group(GroupNames.GROUND_PATCHES)
	tick_timer = CustomTimer.new()
	add_child(tick_timer)
	tick_timer.unscaled_base_value = TICK_SECONDS
	tick_timer.timeout.connect(_tick)
	tick_timer.start()
	queue_redraw()


func _tick() -> void:
	if not is_instance_valid(tower) or tower.level == null:
		queue_free()
		return
	var reach : float = RADIUS_TILES * Utils.TILE_SIZE
	for enemy in tower.level.existing_enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.is_flying or enemy.is_burrowed:
			continue
		if enemy.global_position.distance_to(global_position) > reach:
			continue
		var hit : DamageData = DamageData.new()
		hit.damage_type = damage_type
		hit.damage = tick_damage
		hit.is_overtime = true
		hit.source = tower
		enemy.take_damage(hit)
		hit.free()
	ticks_left -= 1
	if ticks_left <= 0:
		queue_free()


#a flat disc on whole pixels, under the units
func _draw() -> void:
	draw_circle(Vector2.ZERO, roundf(RADIUS_TILES * Utils.TILE_SIZE), COLORS.get(damage_type, COLORS[Utils.DamageType.Physical]))
