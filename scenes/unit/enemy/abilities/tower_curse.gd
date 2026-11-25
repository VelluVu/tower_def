class_name TowerCurse
extends Node2D

## The bog witch's hex on a tower (CurseTowersAbility): it attacks slower (`slow` off its attack speed bonus, a Flat
## modifier like the cards' own) for `seconds`. A tower carries one curse at a time; a new one restarts it.

const NAME : String = "TowerCurse"
const COLOR : Color = Color("b55088")
const RADIUS : float = 6.0

var tower : Tower = null
var modifier : ModifierData = null
var timer : CustomTimer = null


## Curses the tower, or restarts the curse it has; true when it got a new one. The ability skips cursed towers, so
## a restart only comes from a second witch.
static func give(target : Tower, slow : float, seconds : float) -> bool:
	if not is_instance_valid(target) or target.is_dead:
		return false
	var old : TowerCurse = target.get_node_or_null(NAME) as TowerCurse
	if old != null:
		old.timer.start()
		return false
	var curse : TowerCurse = TowerCurse.new()
	curse.name = NAME
	curse.tower = target
	curse.modifier = ModifierData.new()
	curse.modifier.modifier_type = Utils.ModifierType.StatModifier
	curse.modifier.calculate_type = Utils.ModifyType.Flat
	curse.modifier.stat_type = Utils.StatType.AttackSpeed
	curse.modifier.value = -slow
	target.add_child(curse)
	curse.timer.unscaled_base_value = seconds
	curse.timer.start()
	return true


func _ready() -> void:
	z_index = 2
	position = Vector2(0, -12)
	timer = CustomTimer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_end)
	tower.modifier_manager.add_modifier(modifier)


func _end() -> void:
	if is_instance_valid(tower) and not tower.is_queued_for_deletion():
		tower.modifier_manager.remove_modifier(modifier)
	queue_free()


#a small hex sigil above the tower
func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 12, COLOR, 1.0)
	draw_line(Vector2(-3, -3), Vector2(3, 3), COLOR, 1.0)
	draw_line(Vector2(3, -3), Vector2(-3, 3), COLOR, 1.0)
