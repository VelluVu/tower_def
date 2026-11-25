@tool
class_name TalentEffect
extends Resource

## One effect of a talent node, scaled by the node's rank. Building stat effects go on every
## matching building of a level as a unit stat modifier, like the XP cards.

enum Kind
{
	BuildingStat,
	StartGold,
	#an evolve tier unlock: EvolveTierData reads the node's rank, nothing is applied here
	UnlockTier,
	#the rest are level-wide, summed by LevelTalents (2026-11-16):
	#enemies in `condition` take value more damage (from `buildings`, of `elements` damage; 0 = any)
	Vulnerability,
	#enemies in `condition` deal value less damage to buildings
	Weakness,
	#maze slow points (0.03 = 3 points stronger)
	MazeSlow,
	#seconds added to every enemy turn pause
	TurnPause,
	#cards more per level-up offer
	CardOffer,
	#share more early-start bonus
	EarlyStartBonus,
	#gold when a wave is cleared
	WaveGold,
	#share off every upgrade and evolve price
	UpgradeDiscount,
	#share longer freezes
	FreezeLonger,
	#seconds added to every freeze
	FreezeExtra,
	#walls heal this share of their max health a second, towers and traps a quarter of it
	Mending,
	#share more Fortress thorns
	WallThorns,
	#walls take this share less damage (of `elements` damage; 0 = any)
	WallArmor,
	#mechanics (2026-11-16, TalentMechanics): every `every`th attack of a matching tower strikes (`strike`)
	Strike,
	#enemies dying in `condition` burst: value of their max health as `elements` damage to enemies within radius_tiles
	DeathBurst,
	#an elder dragon in each castle breathes fire every `interval` s: value of max health to enemies within radius_tiles;
	#the first enemy to reach each castle every wave costs no life
	CastleDragon,
	#selling a tower or trap also refunds this share of the gold spent on its upgrades (Salvage)
	SellRefund,
	#the first upgrade of each tower and trap costs this share less (Hoard)
	FirstUpgradeDiscount,
	#a Buffer's buffs value share stronger, and pips more in its budget (matched to the Buffer's element; 2026-11-24)
	BufferStrength,
	BufferBudget,
}

## What a Strike does, at its target (radius_tiles around it; 0 = the target only) or around the tower (at_tower:
## the tower's range times range_factor): value is the share of the tower's hit (Blast), seconds (Freeze), extra
## hits that bring the tower's stacks (Stacks), or bolts to the nearest enemies at half the hit (Split).
enum StrikeKind
{
	Blast,
	Freeze,
	Stacks,
	Split,
}

## The stats an element tree gives a tower that only leans to the element (no burn, slow or mechanic stats).
const LEANING_STATS : Array[Utils.StatType] = [Utils.StatType.Damage, Utils.StatType.AttackSpeed, Utils.StatType.AttackRange,
	Utils.StatType.CriticalChance, Utils.StatType.CriticalMultiplier]

## For Vulnerability and Weakness: which enemies count.
enum Condition
{
	Any,
	Burning,
	Poisoned,
	Frozen,
	#slowed by Frost stacks, or frozen
	Chilled,
	#in the air (Skyhook: more damage against flyers)
	Flying,
}

## Building flags, matched by TalentEffect.get_building_flag.
const BOLTER : int = 1 << 0
const NOVA : int = 1 << 1
const BEAMER : int = 1 << 2
const TRAP : int = 1 << 3
const WALL : int = 1 << 4
const MORTAR : int = 1 << 5
const BUFFER : int = 1 << 6
const BREATHER : int = 1 << 7
const SPOTTER : int = 1 << 8
const HARPOONER : int = 1 << 9
const HATCHERY : int = 1 << 10
const EGG_BOMB : int = 1 << 11
const SPIKE_FIELD : int = 1 << 12
const HOARD_KEEPER : int = 1 << 13
const SHREDDER : int = 1 << 14
const ELDER_DRAKE : int = 1 << 15

@export var kind : Kind = Kind.BuildingStat
@export_flags("Bolter", "Nova", "Beamer", "Trap", "Wall", "Mortar", "Buffer", "Breather", "Spotter", "Harpooner", "Hatchery", "Egg Bomb", "Spike Field", "Hoard Keeper", "Shredder", "Elder Drake") var buildings : int = 0
## The element the building must have; none means any element.
@export_flags("Physical", "Fire", "Frost", "Poison") var elements : int = 0
@export var stat_type : Utils.StatType = Utils.StatType.Damage
@export var modify_type : Utils.ModifyType = Utils.ModifyType.Additive
@export var value_per_rank : float = 0.0
@export var condition : Condition = Condition.Any
## Vulnerability: the value is per poison stack on the enemy (Necrosis, Overdose).
@export var per_stack : bool = false
@export_group("Mechanics")
@export var strike : StrikeKind = StrikeKind.Blast
## Strike: every how many attacks of the tower.
@export var every : int = 0
@export var at_tower : bool = false
@export var range_factor : float = 1.0
@export var radius_tiles : float = 0.0
## CastleDragon: seconds between breaths.
@export var interval : float = 0.0


## Whether an enemy is in a condition (burning, poisoned, frozen, chilled).
static func enemy_in(enemy : Enemy, wanted : Condition) -> bool:
	match wanted:
		Condition.Burning:
			return not enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Fire).is_empty()
		Condition.Poisoned:
			return not enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison).is_empty()
		Condition.Frozen:
			return enemy.is_frozen
		Condition.Chilled:
			return enemy.is_frozen or not enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Frost).is_empty()
		Condition.Flying:
			return enemy.is_flying
	return true


## leaning: the element a tower without an element leans to (LevelTalents.get_leaning_element); such a tower gets
## that tree's basic stat talents, so points in the favourite tree help from the first tower on (2026-11-16).
func fits(building : Building, leaning : int = 0) -> bool:
	if kind != Kind.BuildingStat:
		return false

	if buildings & get_building_flag(building) == 0:
		return false

	if elements != 0 and building.evolve_tree != null and not building.evolve_tree.is_element_chosen and elements & building.evolve_tree.evolve_element == 0:
		return leaning != 0 and elements & leaning != 0 and stat_type in LEANING_STATS

	if elements == 0 or building.evolve_tree == null:
		return elements == 0

	return elements & building.evolve_tree.evolve_element != 0


func get_modifier_data(rank : int) -> ModifierData:
	var data : ModifierData = ModifierData.new()
	data.modifier_type = Utils.ModifierType.StatModifier
	data.stat_type = stat_type
	data.calculate_type = modify_type
	data.value = value_per_rank * rank
	return data


static func get_building_flag(building : Building) -> int:
	if building is Wall:
		return WALL

	#a trap too, but with its own talents
	if building is EggBomb:
		return EGG_BOMB
	if building.skill is SpikeStrike:
		return SPIKE_FIELD
	if building is HoardKeeper:
		return HOARD_KEEPER
	if building is Shredder:
		return SHREDDER
	if building is ElderDrake:
		return ELDER_DRAKE

	if building is Trap:
		return TRAP

	if building.skill == null:
		return 0

	match building.skill.skill_type:
		Utils.SkillType.Projectile:
			return BOLTER
		Utils.SkillType.Area:
			return NOVA
		Utils.SkillType.Beaming:
			return BEAMER
		Utils.SkillType.Artillery:
			return MORTAR
		Utils.SkillType.Support:
			return BUFFER
		Utils.SkillType.Breath:
			return BREATHER
		Utils.SkillType.Sniper:
			return SPOTTER
		Utils.SkillType.Harpoon:
			return HARPOONER
		Utils.SkillType.Guard:
			return HATCHERY

	return 0
