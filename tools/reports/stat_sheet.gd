extends RefCounted

## `python tools/gd.py stats`: base stats of every building and enemy, unit and skill values added up
## (the way ModifierManager combines them), plus the skill timings.

const BUILDINGS_FOLDER : String = "res://scenes/unit/building/buildings"
const ENEMIES_FOLDER : String = "res://scenes/unit/enemy/enemies"
const SCENE_EXTENSION : String = ".tscn"


func run(_kit : TestKit, _args : PackedStringArray) -> void:
	print("BUILDINGS  price  health  damage  range  cast  cooldown  active  crit  crit x")
	for scene_name in _scene_names(BUILDINGS_FOLDER):
		var unit : Node = load(BUILDINGS_FOLDER.path_join(scene_name)).instantiate()
		var values : Dictionary = _combined_stats(unit)
		var skill : Skill = _find_skill(unit)
		print("  %-14s %5s %7s %7s %6s %5s %9s %7s %5s %7s" % [scene_name.get_basename(),
			_value(values, Utils.StatType.Price), _value(values, Utils.StatType.MaxHealth), _value(values, Utils.StatType.Damage),
			_value(values, Utils.StatType.AttackRange), _timing(skill, "base_cast_time"), _timing(skill, "base_cooldown"),
			_timing(skill, "base_active_time"), _value(values, Utils.StatType.CriticalChance), _value(values, Utils.StatType.CriticalMultiplier)])
		unit.free()

	print("ENEMIES   health  speed  life dmg  gold  xp  melee dmg  melee every")
	for scene_name in _scene_names(ENEMIES_FOLDER):
		var unit : Node = load(ENEMIES_FOLDER.path_join(scene_name)).instantiate()
		var unit_values : Dictionary = _stats_of(unit.get_node("Stats"))
		var skill : Skill = _find_skill(unit)
		var skill_values : Dictionary = _stats_of(skill.get_node_or_null("Stats")) if skill != null else {}
		#the leak cost is the unit's own damage; a melee hit adds the unit's and the skill's damage
		var melee : float = unit_values.get(Utils.StatType.Damage, 0.0) + skill_values.get(Utils.StatType.Damage, 0.0)
		var every : float = (skill.base_cast_time + skill.base_cooldown) if skill != null else 0.0
		print("  %-14s %5s %6s %8s %5s %4s %9s %10ss" % [scene_name.get_basename(),
			_value(unit_values, Utils.StatType.MaxHealth), _value(unit_values, Utils.StatType.Speed), _value(unit_values, Utils.StatType.Damage),
			_value(unit_values, Utils.StatType.Price), UpgradeRules.kill_xp(unit_values.get(Utils.StatType.MaxHealth, 0.0), (unit as Enemy).xp_multiplier), melee, every])
		unit.free()


func _combined_stats(unit : Node) -> Dictionary:
	var values : Dictionary = _stats_of(unit.get_node("Stats"))
	var skill : Skill = _find_skill(unit)
	if skill != null:
		var skill_values : Dictionary = _stats_of(skill.get_node_or_null("Stats"))
		for stat_type in skill_values:
			values[stat_type] = values.get(stat_type, 0.0) + skill_values[stat_type]
	return values


func _stats_of(stats_node : Node) -> Dictionary:
	var values : Dictionary = {}
	if stats_node == null:
		return values
	for stat in stats_node.get_children():
		if stat is Stat:
			values[stat.type] = stat.base_value
	return values


func _find_skill(unit : Node) -> Skill:
	for child in unit.get_children():
		if child is Skill:
			return child
	return null


func _timing(skill : Skill, property : String) -> String:
	return "-" if skill == null else str(skill.get(property))


func _value(values : Dictionary, stat_type : Utils.StatType) -> String:
	return str(values.get(stat_type, 0.0))


func _scene_names(folder : String) -> PackedStringArray:
	return Array(DirAccess.get_files_at(folder)).filter(func(file : String) -> bool: return file.ends_with(SCENE_EXTENSION))
