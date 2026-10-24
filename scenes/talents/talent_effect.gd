class_name TalentEffect
extends Resource

## One effect of a talent node, scaled by the node's rank. Building stat effects go on every
## matching building of a level as a unit stat modifier, like the XP cards.

enum Kind
{
	BuildingStat,
	StartGold,
}

## Building flags, matched by TalentEffect.get_building_flag.
const BOLTER : int = 1 << 0
const NOVA : int = 1 << 1
const BEAMER : int = 1 << 2
const TRAP : int = 1 << 3
const WALL : int = 1 << 4

@export var kind : Kind = Kind.BuildingStat
@export_flags("Bolter", "Nova", "Beamer", "Trap", "Wall") var buildings : int = 0
## The element the building must have; none means any element.
@export_flags("Physical", "Fire", "Frost", "Poison") var elements : int = 0
@export var stat_type : Utils.StatType = Utils.StatType.Damage
@export var modify_type : Utils.ModifyType = Utils.ModifyType.Additive
@export var value_per_rank : float = 0.0


func fits(building : Building) -> bool:
	if kind != Kind.BuildingStat:
		return false

	if buildings & get_building_flag(building) == 0:
		return false

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

	return 0
