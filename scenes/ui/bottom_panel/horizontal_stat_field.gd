class_name HorizontalStatField
extends HBoxContainer


@onready var stat_name : Label = $StatName
@onready var value : Label = $Value


func set_field(_stat_type : Utils.StatType = Utils.StatType.Health, actor_stats : Stats = null, main_skill : Skill = null) -> void:
	if actor_stats == null:
		stat_name.text = ""
		value.text = ""
		return
		
	match(_stat_type):
		Utils.StatType.Health:
			stat_name.text = "Health:"
			value.text = str(actor_stats.get_stat_value(Utils.StatType.Health)) + "/" + str(actor_stats.get_stat_value(Utils.StatType.MaxHealth))
		Utils.StatType.Damage:
			stat_name.text = "Damage:"
			value.text = str(round(main_skill.stats.get_stat_value(Utils.StatType.Damage)))
		Utils.StatType.AttackSpeed:
			stat_name.text = "Attack Speed:"
			value.text = str(snapped(main_skill.attack_speed, 0.01))
		Utils.StatType.CriticalChance:
			stat_name.text = "Critical Chance:"
			value.text = str(snapped((main_skill.stats.get_stat_value(Utils.StatType.CriticalChance)), 0.01) * 100.0) + "%"
		Utils.StatType.CriticalMultiplier:
			stat_name.text = "Critical Multiplier:"
			value.text = str(snapped(main_skill.stats.get_stat_value(Utils.StatType.CriticalMultiplier), 0.01))
		Utils.StatType.AttackRange:
			stat_name.text = "Attack Range:"
			value.text = str(main_skill.stats.get_stat_value(Utils.StatType.AttackRange))
		Utils.StatType.Price:
			stat_name.text = "Price:"
			value.text = str(actor_stats.get_stat_value(Utils.StatType.Price))
