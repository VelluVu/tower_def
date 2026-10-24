class_name StatCap
extends Resource

## Caps the summed XP card bonus on one stat of one building. Gold upgrades and elements don't count.

@export var stat_type : Utils.StatType = Utils.StatType.Damage
#past this card total the cards count at UpgradeRules.SOFT_CAP_EFFICIENCY
@export var soft_cap : float = 0.5
#the card total never goes past this
@export var hard_cap : float = 1.0
