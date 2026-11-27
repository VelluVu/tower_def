class_name EvolveResource
extends Resource

## Buildings: a stat modifier on every building the card fits. Gold: gold once, when picked.
## Xp: more XP from every kill for the rest of the level. MazeDamage: enemies in the maze (next to a
## building) take more damage from towers. MazeSlow: enemies in the maze walk slower.
#level-wide since 2026-11-27: KillGold (Bounty, a chance of 1 more gold a kill), UpgradeDiscount (Thrift), WallArmor (Stonemason)
enum CardTarget { Buildings, Gold, Xp, MazeDamage, MazeSlow, KillGold, UpgradeDiscount, WallArmor }
## Rare cards come up less often in an offer (UpgradeRules.RARE_OFFER_WEIGHT) and are marked on the card.
enum Rarity { Common, Rare }

@export var evolve_icon : CompressedTexture2D = null
@export var evolve_level_reguirement : int = 0
@export var card_target : CardTarget = CardTarget.Buildings
#walls take only the cards marked for them (towers and traps still go by fits_tower)
@export var fits_walls : bool = false
#how many times the card can be picked in one level, 0 = no limit
@export var max_picks : int = 0

@export var modifier_type : Utils.ModifierType
@export_flags("Melee", "Projectile", "Area", "Beaming", "Artillery", "Support", "Breath", "Sniper", "Harpoon", "Guard", "Blast") var skill_type : int = 0
@export var skill_name : String = "Skill"

@export_flags("Physical", "Fire", "Frost", "Poison") var elements : int = 0

@export var modify_stat_type : Utils.StatType = Utils.StatType.Damage
@export var modify_type : Utils.ModifyType = Utils.ModifyType.Multiply

@export var is_randomized_modify_value : bool = true
@export var is_percent : bool = true
#base value; each UpgradeCard rolls its own bonus from it (UpgradeRules.roll_value)
@export var modify_value : float = 0.1
@export var evolve_name : String = "All Damage"
@export var rarity : Rarity = Rarity.Common
## Shown under the name instead of the value (mechanic cards, whose number alone says little).
## "{value}" in it shows the card's value.
@export_multiline var description : String = ""

@export_group("Talent unlock")
## An element card from a talent tree: offered only once the tree (TalentTree.id) has talent_ranks ranks learned.
@export var talent_tree : StringName = &""
@export var talent_ranks : int = 0

@export_group("Drawback")
## A trade-off card: the bonus comes with this penalty on another stat, never capped, never rolled. A positive value
## makes it a paired card's second stat instead (Flash Freeze's freeze time, Split Shot's shard share; 2026-11-27).
@export var has_drawback : bool = false
@export var drawback_stat_type : Utils.StatType = Utils.StatType.AttackRange
@export var drawback_modify_type : Utils.ModifyType = Utils.ModifyType.Additive
#negative: -0.2 with Additive = 20% less
@export var drawback_value : float = -0.2
@export var drawback_is_percent : bool = true

func get_modifier_data() -> ModifierData:
	var modifier_data : ModifierData = ModifierData.new()
	modifier_data.modifier_type = modifier_type
	modifier_data.stat_type = modify_stat_type
	modifier_data.calculate_type = modify_type
	modifier_data.value = modify_value
	modifier_data.skill_name = skill_name
	modifier_data.skill_type = skill_type
	return modifier_data


func get_drawback_modifier_data() -> ModifierData:
	var modifier_data : ModifierData = ModifierData.new()
	modifier_data.modifier_type = Utils.ModifierType.StatModifier
	modifier_data.stat_type = drawback_stat_type
	modifier_data.calculate_type = drawback_modify_type
	modifier_data.value = drawback_value
	return modifier_data


func evolve(_actor : Node) -> void:
	_actor.modifier_manager.add_modifier(get_modifier_data())
