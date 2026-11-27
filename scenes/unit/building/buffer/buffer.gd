class_name Buffer
extends Building

## The Buffer (2026-11-24, design doc New Towers): a support drakeling that never attacks. Since 2026-11-26 (the user) it
## throws its buffs: every THROW_SECONDS one throw at the tower in its radius with the least buff time left from it, and
## that tower holds the Buffer's values for BUFF_SECONDS (BufferAuras.throw), so it keeps a handful of towers buffed and
## its radius and the throws' rhythm decide how many. The towers in reach get the Buffer's tracks: pips bought one at a time from a budget, at most
## MAX_PIPS per track, so a focused or a broad buff is the player's choice. Several Buffers never stack: a building
## takes the strongest value per stat (BufferAuras). Its element passes on as a chance on hit; T2 weakens the enemies
## in the aura, T3 roars now and then (Commander's Roar). The Mend track (2026-11-27, the user: a maxed wall and Buffer
## hold well, but a stack of attackers the towers cannot thin out overwhelms the block) heals the walls in its aura at a
## fixed rate, towers and traps a quarter of it; siege attackers (bosses, enemies no guard holds) halve it on the wall
## they hit.

signal aura_changed

const PIP_BUDGET : int = 8
const THROW_SECONDS : float = 1.0
const BUFF_SECONDS : float = 6.0
const MAX_PIPS : int = 5
## The tracks in the selection card's order.
const TRACKS : Array[Utils.StatType] = [Utils.StatType.Damage, Utils.StatType.AttackSpeed, Utils.StatType.AttackRange,
	Utils.StatType.CriticalChance, Utils.StatType.EffectPotency, Utils.StatType.AuraRadius, Utils.StatType.WallMend]
## What one pip gives a buffed building: [modify type, value]. Damage is Additive like cards and upgrades, the rest
## Flat like the tower stats whose base is 0 (attack speed, crit, potency) or a reach in tiles (range).
const PIP_VALUES : Dictionary[Utils.StatType, Array] = {
	Utils.StatType.Damage: [Utils.ModifyType.Additive, 0.06],
	Utils.StatType.AttackSpeed: [Utils.ModifyType.Flat, 0.04],
	Utils.StatType.AttackRange: [Utils.ModifyType.Flat, 0.1],
	Utils.StatType.CriticalChance: [Utils.ModifyType.Flat, 0.02],
	Utils.StatType.EffectPotency: [Utils.ModifyType.Flat, 0.06],
	#its own reach in tiles, not a buff on the towers
	Utils.StatType.AuraRadius: [Utils.ModifyType.Flat, 0.5],
	#its own healing, a share of max health a second, not a buff on the towers
	Utils.StatType.WallMend: [Utils.ModifyType.Flat, 0.01],
}
const TRACK_NAMES : Dictionary[Utils.StatType, String] = {
	Utils.StatType.Damage: "Damage",
	Utils.StatType.AttackSpeed: "Attack Speed",
	Utils.StatType.AttackRange: "Range",
	Utils.StatType.CriticalChance: "Critical Chance",
	Utils.StatType.EffectPotency: "Effect Potency",
	Utils.StatType.AuraRadius: "Radius",
	Utils.StatType.WallMend: "Mend",
}
const TRACK_ICONS : Dictionary[Utils.StatType, String] = {
	Utils.StatType.Damage: "res://assets/art/ui/card_icons/damage_icon.png",
	Utils.StatType.AttackSpeed: "res://assets/art/ui/card_icons/attack_speed_icon.png",
	Utils.StatType.AttackRange: "res://assets/art/ui/card_icons/attack_range_icon.png",
	Utils.StatType.CriticalChance: "res://assets/art/ui/card_icons/critical_chance_icon.png",
	Utils.StatType.EffectPotency: "res://assets/art/ui/card_icons/effect_potency_icon.png",
	Utils.StatType.AuraRadius: "res://assets/art/ui/card_icons/long_sight_icon.png",
	#borrowed until a mend icon is drawn
	Utils.StatType.WallMend: "res://assets/art/ui/card_icons/tangled_maze_icon.png",
}
## Each pip's price as a share of the Buffer's price, by how many pips it already has.
const PIP_COST_RATIOS : Array[float] = [0.4, 0.5, 0.6, 0.7, 0.8, 1.0, 1.2, 1.4]
## A Fire, Frost or Poison Buffer: the chance a buffed building's direct hit adds a stack of its element, by tier.
const PASS_CHANCE_BY_TIER : Array[float] = [0.0, 0.2, 0.25, 0.3]
## A Physical Buffer: the share of resistances the buffed buildings ignore.
const PHYSICAL_PENETRATION : float = 0.1
## T2: enemies in the aura take this much more damage from buildings.
const WEAKEN_SHARE : float = 0.1
## T3 Commander's Roar: every ROAR_INTERVAL seconds the buffed buildings attack ROAR_ATTACK_SPEED faster for ROAR_SECONDS.
const ROAR_INTERVAL : float = 12.0
const ROAR_SECONDS : float = 3.0
const ROAR_ATTACK_SPEED : float = 0.4
const ROAR_ANIMATION : StringName = &"ROAR"
const MEND_SECONDS : float = 1.0
## Towers and traps in the aura mend this share of a wall's rate.
const MEND_TOWER_SHARE : float = 0.25

var pips : Dictionary[Utils.StatType, int] = {}
var throw_timer : CustomTimer = null
var mend_timer : CustomTimer = null

var total_pips : int :
	get:
		var total : int = 0
		for stat in pips:
			total += pips[stat]
		return total

## PIP_BUDGET plus the Deep Reserve talents.
var pip_budget : int :
	get:
		return PIP_BUDGET + roundi(_talent_bonus(TalentEffect.Kind.BufferBudget))

var tier : int :
	get:
		return evolve_tree.tier if evolve_tree != null else 0

## The element it passes on; None before an element is bought.
var element : Utils.Element :
	get:
		if evolve_tree == null or not evolve_tree.is_element_chosen:
			return Utils.Element.None
		return evolve_tree.evolve_element


func _ready() -> void:
	super()
	throw_timer = CustomTimer.new()
	add_child(throw_timer)
	throw_timer.unscaled_base_value = THROW_SECONDS
	throw_timer.timeout.connect(throw_buff)
	mend_timer = CustomTimer.new()
	add_child(mend_timer)
	mend_timer.unscaled_base_value = MEND_SECONDS
	mend_timer.timeout.connect(mend)
	if evolve_tree != null:
		evolve_tree.element_changed.connect(func(_element : Utils.Element) -> void: aura_changed.emit())
		evolve_tree.tier_changed.connect(func(_tier : int) -> void: aura_changed.emit())


func get_pips(stat : Utils.StatType) -> int:
	return pips.get(stat, 0)


func can_add_pip(stat : Utils.StatType) -> bool:
	return TRACKS.has(stat) and get_pips(stat) < MAX_PIPS and total_pips < pip_budget


func add_pip(stat : Utils.StatType) -> void:
	if not can_add_pip(stat):
		return
	pips[stat] = get_pips(stat) + 1
	aura_changed.emit()


## What this Buffer gives a building in its aura for the stat (0 with no pips): its pips, made stronger by the
## Rallying Cry talents; potency also takes the Buffer's own EffectPotency (the Song talents).
func get_buff(stat : Utils.StatType) -> float:
	if not PIP_VALUES.has(stat) or stat == Utils.StatType.AuraRadius or stat == Utils.StatType.WallMend:
		return 0.0
	var value : float = get_pips(stat) * float(PIP_VALUES[stat][1]) * (1.0 + _talent_bonus(TalentEffect.Kind.BufferStrength))
	if stat == Utils.StatType.EffectPotency:
		value += stats.get_stat_value(Utils.StatType.EffectPotency)
	return value


## The share of a wall's max health it heals a second (0 with no Mend pips), made stronger by the Rallying Cry talents.
func get_mend_rate() -> float:
	return get_pips(Utils.StatType.WallMend) * float(PIP_VALUES[Utils.StatType.WallMend][1]) * (1.0 + _talent_bonus(TalentEffect.Kind.BufferStrength))


## One mend tick: every hurt building in its aura heals (BufferAuras.mend_from).
func mend() -> void:
	if not is_placed or is_dead or level == null or level.buffer_auras == null or get_pips(Utils.StatType.WallMend) == 0:
		return
	level.buffer_auras.mend_from(self, MEND_SECONDS)


## The share of resistances a Physical Buffer's aura ignores (plus its own ResistancePenetration, Sharp Orders).
func get_penetration() -> float:
	return PHYSICAL_PENETRATION + stats.get_stat_value(Utils.StatType.ResistancePenetration)


func _talent_bonus(kind : TalentEffect.Kind) -> float:
	if level == null or level.talents == null:
		return 0.0
	return level.talents.get_buffer_bonus(kind, self)


## The chance its element rides on a buffed building's hit (Fire, Frost, Poison; 0 for Physical or none).
func get_pass_chance() -> float:
	if element == Utils.Element.None or element == Utils.Element.Physical:
		return 0.0
	#its own EffectChance: the Zeal talents
	return PASS_CHANCE_BY_TIER[clampi(tier, 0, PASS_CHANCE_BY_TIER.size() - 1)] + stats.get_stat_value(Utils.StatType.EffectChance)


## One throw: the tower in its radius with the least buff time left from it gets its values for BUFF_SECONDS.
func throw_buff() -> void:
	if not is_placed or is_dead or level == null or level.buffer_auras == null:
		return
	level.buffer_auras.throw_from(self)


## Its range plus the radius pips.
func _get_radius() -> float:
	return super() + get_pips(Utils.StatType.AuraRadius) * float(PIP_VALUES[Utils.StatType.AuraRadius][1]) * Utils.TILE_SIZE


func covers(position_to_check : Vector2) -> bool:
	return global_position.distance_to(position_to_check) <= radius


## Plays the roar once (T3), then goes back to idling.
func play_roar() -> void:
	if animation_control == null or not animation_control.sprite_frames.has_animation(ROAR_ANIMATION):
		return
	animation_control.play_animation(ROAR_ANIMATION)
	#an element swaps the sprite, so the idle comes back through this one-shot connection on the current one
	if not animation_control.animation_finished.is_connected(_on_roar_finished):
		animation_control.animation_finished.connect(_on_roar_finished, CONNECT_ONE_SHOT)


func _on_roar_finished() -> void:
	if animation_control != null and animation_control.sprite_frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION):
		animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)


func _enable_tower() -> void:
	super()
	#the first throw at once, then one every THROW_SECONDS
	throw_buff.call_deferred()
	throw_timer.start()
	mend_timer.start()
	if animation_control != null and animation_control.sprite_frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION):
		animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)
