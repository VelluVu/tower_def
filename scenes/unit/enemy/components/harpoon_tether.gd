class_name HarpoonTether
extends Node2D

## A Harpooner's chain on an enemy (2026-11-24): for its time the enemy moves slower and the chain is drawn from the
## enemy to the tower. A flyer is dragged down for good and walks the maze from where it lands (LandAbility.land); a
## boss flyer is held where it is for BOSS_HOLD_SECONDS instead, at most once every BOSS_HOLD_COOLDOWN. On landing a
## Frost harpoon freezes the flyer for a moment and a Poison one marks it for every element (the armour loss).
## Made on the enemy by the first harpoon (HarpoonTether.attach); a new harpoon renews the time and keeps the stronger slow.
## A Frost harpoon's slow goes past the slow floor (ModifierData.ignores_slow_floor), never to a stop; every tether
## slows enemies immune or resistant to slows too: a standard bearer's banner, bosses at full strength
## (ModifierData.pierces_slow_immunity; 2026-11-25, the user).

const NODE_NAME : String = "Tether"
const BOSS_HOLD_SECONDS : float = 3.0
const BOSS_HOLD_COOLDOWN : float = 10.0
## Frost: a grounded flyer freezes this long where it lands.
const LANDING_FREEZE_SECONDS : float = 1.0
## Poison: a grounded flyer takes this share more of every element for ROT_SECONDS (EnemyMarks).
const ROT_SHARE : float = 0.15
const ROT_SECONDS : float = 5.0
## The harpoon's bleed (the user, 2026-11-26): every harpoon hit starts a Physical bleed stack of BLEED_TICKS ticks, each
## BLEED_SHARE of the hit; and while the tether holds and BLEED_AFTER_SECONDS after, every bleed on the enemy (any
## tower's: a Physical effect tick) hurts BLEED_VULNERABILITY more.
const BLEED_NAME : String = "HarpoonBleed"
const BLEED_SHARE : float = 0.25
const BLEED_TICKS : int = 3
const BLEED_STACKS : int = 3
const BLEED_VULNERABILITY : float = 0.5
const BLEED_AFTER_SECONDS : float = 3.0
## The chain: a link every LINK_STEP pixels, drawn LINK_SIZE wide in the chain colours.
const LINK_STEP : float = 3.0
const LINK_SIZE : float = 2.0
const CHAIN_LIGHT : Color = Color(0.75, 0.8, 0.86)
const CHAIN_DARK : Color = Color(0.35, 0.41, 0.53)

var enemy : Enemy = null
var tower : WeakRef = null
var seconds_left : float = 0.0
var hold_left : float = 0.0
#counts down from BOSS_HOLD_COOLDOWN after a boss hold; a new hold waits for 0
var hold_cooldown : float = 0.0
var slow : ModifierData = null
#counts down while the enemy bleeds harder: the tether's time plus BLEED_AFTER_SECONDS
var vulnerable_left : float = 0.0


## Tethers the target to the tower for seconds, slowing it by slow (0.5 = half speed); returns its tether node.
static func attach(target : Enemy, from_tower : Building, seconds : float, slow_share : float) -> HarpoonTether:
	if target.is_dead or seconds <= 0.0:
		return null
	var node : HarpoonTether = target.get_node_or_null(NodePath(NODE_NAME)) as HarpoonTether
	if node == null:
		node = HarpoonTether.new()
		node.name = NODE_NAME
		node.enemy = target
		node.z_index = 1
		target.add_child(node)
	node.tower = weakref(from_tower)
	node.seconds_left = maxf(node.seconds_left, seconds)
	node.vulnerable_left = maxf(node.vulnerable_left, node.seconds_left + BLEED_AFTER_SECONDS)
	node._set_slow(slow_share, is_frost(from_tower))
	if target.is_flying:
		node._drag_down(from_tower)
	node.queue_redraw()
	return node


static func is_frost(from_tower : Building) -> bool:
	return from_tower.evolve_tree != null and from_tower.evolve_tree.is_element_chosen and from_tower.evolve_tree.evolve_element == Utils.Element.Frost


## Starts the harpoon's bleed on the target: one OvertimeEffectData per Harpooner, made on first use and freed with it.
static func bleed(target : Enemy, from_tower : Building, hit_damage : float) -> void:
	if target.is_dead or hit_damage <= 0.0 or target.overtime_effect_handler == null:
		return
	var data : OvertimeEffectData = from_tower.get_node_or_null(NodePath(BLEED_NAME)) as OvertimeEffectData
	if data == null:
		data = OvertimeEffectData.new()
		data.name = BLEED_NAME
		data.damage_type = Utils.DamageType.Physical
		data.effectType = Utils.OvertimeEffectType.Stack
		data.hit_share = BLEED_SHARE
		data.max_count = BLEED_TICKS
		data.max_stacks = BLEED_STACKS
		from_tower.add_child(data)
	target.overtime_effect_handler.add_overtime_effect(data, hit_damage)


## A bleed tick (a Physical effect tick) on an enemy a harpoon tore lately: 1 + BLEED_VULNERABILITY, else 1.
static func get_bleed_factor(target : Enemy, hit : DamageData) -> float:
	if not hit.is_overtime or hit.damage_type != Utils.DamageType.Physical:
		return 1.0
	var node : HarpoonTether = target.get_node_or_null(NodePath(NODE_NAME)) as HarpoonTether
	return 1.0 + BLEED_VULNERABILITY if node != null and node.vulnerable_left > 0.0 else 1.0


func is_tethered() -> bool:
	return seconds_left > 0.0


func _set_slow(share : float, is_deep : bool = false) -> void:
	share = clampf(share, 0.0, 0.95)
	#a deep (Frost) slow beats a floored one; of the same kind the stronger stays
	if slow != null and (slow.ignores_slow_floor and not is_deep or slow.ignores_slow_floor == is_deep and -slow.value >= share):
		return
	if slow != null:
		enemy.modifier_manager.remove_modifier(slow)
	slow = null
	if share <= 0.0:
		return
	slow = ModifierData.new()
	slow.stat_type = Utils.StatType.Speed
	slow.calculate_type = Utils.ModifyType.Multiply
	slow.value = -share
	slow.ignores_slow_floor = is_deep
	slow.pierces_slow_immunity = true
	enemy.modifier_manager.add_modifier(slow)


func _drag_down(from_tower : Building) -> void:
	if enemy.is_boss:
		if hold_cooldown > 0.0:
			return
		hold_left = BOSS_HOLD_SECONDS
		hold_cooldown = BOSS_HOLD_COOLDOWN
		enemy.is_held = true
		return
	LandAbility.land(enemy)
	#Grounded on a trap: it comes down on the nearest trap
	if enemy.level != null and enemy.level.synergies != null:
		enemy.level.synergies.on_grounded(enemy)
	var element : Utils.Element = from_tower.evolve_tree.evolve_element if from_tower.evolve_tree != null else Utils.Element.None
	if element == Utils.Element.Frost:
		enemy.freeze_for(LANDING_FREEZE_SECONDS)
	elif element == Utils.Element.Poison:
		for damage_type in [Utils.DamageType.Physical, Utils.DamageType.Fire, Utils.DamageType.Frost, Utils.DamageType.Poison]:
			EnemyMarks.mark(enemy, damage_type, ROT_SHARE, ROT_SECONDS)


func _process(delta : float) -> void:
	var time_scale : float = Utils.game_control.time_scale if Utils.game_control != null else 1.0
	var step : float = delta * time_scale
	hold_cooldown = maxf(hold_cooldown - step, 0.0)
	vulnerable_left = maxf(vulnerable_left - step, 0.0)
	if hold_left > 0.0:
		hold_left -= step
		if hold_left <= 0.0 or enemy.is_dead:
			enemy.is_held = false
	if seconds_left <= 0.0:
		return
	seconds_left -= step
	if seconds_left <= 0.0 or enemy.is_dead:
		seconds_left = 0.0
		if slow != null:
			enemy.modifier_manager.remove_modifier(slow)
			slow = null
	queue_redraw()


#the chain from the enemy's body to the tower, as links on whole pixels
func _draw() -> void:
	if seconds_left <= 0.0 or not is_instance_valid(enemy):
		return
	var anchor : Building = tower.get_ref() as Building if tower != null else null
	if anchor == null or anchor.is_queued_for_deletion():
		return
	var from : Vector2 = to_local(enemy.body_center)
	var to : Vector2 = to_local(anchor.global_position + Vector2(0, -8))
	var length : float = from.distance_to(to)
	var links : int = int(length / LINK_STEP)
	for i in links:
		var at : Vector2 = from.lerp(to, float(i) / maxf(float(links), 1.0)).round()
		draw_rect(Rect2(at - Vector2(LINK_SIZE, LINK_SIZE) * 0.5, Vector2(LINK_SIZE, LINK_SIZE)), CHAIN_LIGHT if i % 2 == 0 else CHAIN_DARK)
