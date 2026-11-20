class_name HorizontalStatField
extends HBoxContainer


const PER_SECOND_TEXT : String = "/s"
const GOLD_TEXT : String = "g"
## Numbers from here up show one decimal, smaller ones two.
const LARGE_NUMBER : float = 10.0
const HEALTH_TOOLTIP : String = "Health: now / most"
const DAMAGE_TOOLTIP : String = "Damage of one hit, before resistances"
const SPEED_TOOLTIP : String = "Attacks per second"
const CRIT_TOOLTIP : String = "Critical hit chance, and how much a critical hit multiplies the damage"
const RANGE_TOOLTIP : String = "Reach in tiles"
const PRICE_TOOLTIP : String = "Its price, refunded when sold. For an enemy: the gold it gives"

@onready var stat_name : Label = $StatName
@onready var value : Label = $Value


func set_field(_stat_type : Utils.StatType = Utils.StatType.Health, actor_stats : Stats = null, main_skill : Skill = null) -> void:
	if actor_stats == null:
		stat_name.text = ""
		value.text = ""
		tooltip_text = ""
		return
		
	match(_stat_type):
		Utils.StatType.Health:
			tooltip_text = HEALTH_TOOLTIP
			stat_name.text = "HP"
			value.text = "%s/%s" % [_format(actor_stats.get_stat_value(Utils.StatType.Health)), _format(actor_stats.get_stat_value(Utils.StatType.MaxHealth))]
		Utils.StatType.Damage:
			tooltip_text = DAMAGE_TOOLTIP
			stat_name.text = "DMG"
			value.text = _format(main_skill.stats.get_stat_value(Utils.StatType.Damage))
		Utils.StatType.AttackSpeed:
			tooltip_text = SPEED_TOOLTIP
			stat_name.text = "SPD"
			value.text = _format(main_skill.attack_speed) + PER_SECOND_TEXT
		Utils.StatType.CriticalChance:
			tooltip_text = CRIT_TOOLTIP
			#chance and multiplier share one field: "10% x2"
			stat_name.text = "CRIT"
			value.text = "%s%% x%s" % [_format(main_skill.stats.get_stat_value(Utils.StatType.CriticalChance) * 100.0), _format(main_skill.stats.get_stat_value(Utils.StatType.CriticalMultiplier))]
		Utils.StatType.AttackRange:
			tooltip_text = RANGE_TOOLTIP
			stat_name.text = "RNG"
			value.text = _format(main_skill.stats.get_stat_value(Utils.StatType.AttackRange))
		Utils.StatType.Price:
			tooltip_text = PRICE_TOOLTIP
			stat_name.text = "COST"
			value.text = _format(actor_stats.get_stat_value(Utils.StatType.Price)) + GOLD_TEXT


#whole numbers without ".0", the rest to two decimals, one from LARGE_NUMBER up (damage 33.1, not 33.12)
static func _format(number : float) -> String:
	var snapped_number : float = snappedf(number, 0.1 if absf(number) >= LARGE_NUMBER else 0.01)
	if is_equal_approx(snapped_number, roundf(snapped_number)):
		return str(int(roundf(snapped_number)))
	return str(snapped_number)
