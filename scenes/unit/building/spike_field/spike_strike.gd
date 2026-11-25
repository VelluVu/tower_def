class_name SpikeStrike
extends MeleeAttack

## The Spike Field's spikes: when the trap is ready and something walks on it, the spikes shoot up and every enemy
## on the field takes the hit (not just the first, as the Leopard's claws do) and is slowed a little for a moment
## (SpikeSlow). Flyers pass over unless the trap can hit air; tunnel rats run under. The trap never breaks.

## Speed taken off a struck enemy, and for how long (SpikeSlow).
@export var slow_share : float = 0.15
@export var slow_seconds : float = 1.0


func activate() -> void:
	super()
	#MeleeAttack opens its area for the one target; the spikes strike everything on the field at once instead
	activate_collision_detection(false)
	_strike_all()


func _on_attack_area_body_entered(_body : Node2D) -> void:
	pass


func _strike_all() -> void:
	if actor == null or not "targets" in actor:
		return
	var synergies : Synergies = actor.level.synergies if actor.level != null else null
	var has_chilled : bool = false
	for candidate in actor.targets.duplicate():
		if not is_instance_valid(candidate) or candidate is not Enemy:
			continue
		var enemy : Enemy = candidate
		if not EnemyQuery.is_hittable(enemy) or enemy.ignores_traps or (enemy.is_flying and not actor.can_hit_air):
			continue
		if synergies != null and not has_chilled:
			has_chilled = synergies.is_chilled(enemy)
		var hit : DamageData = damage_data
		enemy.take_damage(hit)
		hit.queue_free()
		if slow_share > 0.0 and not enemy.is_dead:
			SpikeSlow.give(enemy, slow_share, slow_seconds)
	#Cold feet (synergy): the spikes strike faster while chilled enemies stand on them
	if synergies != null:
		synergies.update_cold_feet(actor as Trap, has_chilled)
