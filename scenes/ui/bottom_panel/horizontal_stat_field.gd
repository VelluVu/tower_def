class_name HorizontalStatField
extends HBoxContainer


const PER_SECOND_TEXT : String = "/s"
const GOLD_TEXT : String = "g"

@onready var stat_name : Label = $StatName
@onready var value : Label = $Value


func set_field(_stat_type : Utils.StatType = Utils.StatType.Health, actor_stats : Stats = null, main_skill : Skill = null) -> void:
	if actor_stats == null:
		stat_name.text = ""
		value.text = ""
		return
		
	match(_stat_type):
		Utils.StatType.Health:
			stat_name.text = "HP"
			value.text = "%s/%s" % [_format(actor_stats.get_stat_value(Utils.StatType.Health)), _format(actor_stats.get_stat_value(Utils.StatType.MaxHealth))]
		Utils.StatType.Damage:
			stat_name.text = "DMG"
			value.text = _format(main_skill.stats.get_stat_value(Utils.StatType.Damage))
		Utils.StatType.AttackSpeed:
			stat_name.text = "SPD"
			value.text = _format(main_skill.attack_speed) + PER_SECOND_TEXT
		Utils.StatType.CriticalChance:
			#chance and multiplier share one field: "10% x2"
			stat_name.text = "CRIT"
			value.text = "%s%% x%s" % [_format(main_skill.stats.get_stat_value(Utils.StatType.CriticalChance) * 100.0), _format(main_skill.stats.get_stat_value(Utils.StatType.CriticalMultiplier))]
		Utils.StatType.AttackRange:
			stat_name.text = "RNG"
			value.text = _format(main_skill.stats.get_stat_value(Utils.StatType.AttackRange))
		Utils.StatType.Price:
			stat_name.text = "COST"
			value.text = _format(actor_stats.get_stat_value(Utils.StatType.Price)) + GOLD_TEXT


#whole numbers without ".0", the rest to two decimals
static func _format(number : float) -> String:
	var snapped_number : float = snappedf(number, 0.01)
	if is_equal_approx(snapped_number, roundf(snapped_number)):
		return str(int(roundf(snapped_number)))
	return str(snapped_number)
