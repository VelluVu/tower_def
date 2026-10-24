class_name CardCaps
extends Resource

## The soft and hard caps of the XP cards, one StatCap per stat. A stat without one is not capped.

@export var stat_caps : Array[StatCap] = []
#the XP gain cards are capped like a stat, their total is not a building stat
@export var xp_soft_cap : float = 0.3
@export var xp_hard_cap : float = 0.5


func get_cap(stat_type : Utils.StatType) -> StatCap:
	for cap in stat_caps:
		if cap.stat_type == stat_type:
			return cap

	return null
