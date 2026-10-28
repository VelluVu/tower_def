class_name Tower
extends Building


const RANGE_AREA_OBJECT_NULL_ERROR_MESSAGE : String = "NO RANGE AREA ON TOWER, UNABLE FIND TARGETS!"
#how a silenced tower looks
const SILENCED_MODULATE : Color = Color(0.55, 0.55, 0.7)

@onready var range_area : Area2D = $RangeArea 
@onready var area_shape : CollisionShape2D = $RangeArea/CollisionShape2D

var targets : Array[Node2D]
var target : Node2D = null
#a screech: the tower sees no targets until the timer ends
var silence_timer : CustomTimer = null

var is_silenced : bool :
	get:
		return silence_timer != null and not silence_timer.is_stopped()

var has_target : bool :
	get:
		return not targets.is_empty() and not is_silenced

var behaviour_tree : BeehaveTree :
	get:
		if behaviour_tree == null:
			for child in get_children():
				if child is BeehaveTree:
					behaviour_tree = child
		return behaviour_tree


func _ready() -> void:
	super()
	_connect_range_stats()
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	#an enemy at the end point is freed, so it leaves the targets the same way
	GameSignals.enemy_reached_end_point.connect(_on_enemy_destroyed)

	if range_area == null:
		push_warning(RANGE_AREA_OBJECT_NULL_ERROR_MESSAGE)
	
	if not range_area.body_entered.is_connected(_on_range_area_body_entered):
		range_area.body_entered.connect(_on_range_area_body_entered)
		
	if not range_area.body_exited.is_connected(_on_range_area_body_exited):
		range_area.body_exited.connect(_on_range_area_body_exited)


#range modifiers land on the skill's stat when it has one, so listen to both
func _connect_range_stats() -> void:
	var stat : Stat = stats.get_stat(Utils.StatType.AttackRange)
	
	for range_stat : Stat in [stat, skill.stats.get_stat(Utils.StatType.AttackRange)]:
		if range_stat != null and not range_stat.changed.is_connected(_on_attack_range_stat_changed):
			range_stat.changed.connect(_on_attack_range_stat_changed)
	
	_on_attack_range_stat_changed(stat)


## Stops attacking for seconds (the tree idles, which drops the target); a new silence restarts it.
func silence(seconds : float) -> void:
	if silence_timer == null:
		silence_timer = CustomTimer.new()
		silence_timer.one_shot = true
		add_child(silence_timer)
		silence_timer.timeout.connect(_on_silence_end)

	silence_timer.unscaled_base_value = seconds
	silence_timer.start()
	modulate = SILENCED_MODULATE


func _on_silence_end() -> void:
	modulate = Color.WHITE


func _on_skill_replaced() -> void:
	_connect_range_stats()


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if target == enemy:
		target = null
		
	if targets.has(enemy):
		targets.erase(enemy)


func _on_range_area_body_entered(body: Node2D) -> void:
	targets.append(body)


func _on_range_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		
	targets.erase(body)


func _on_attack_range_stat_changed(_stat : Stat) -> void:
	area_shape.shape.radius = radius


func get_first_target() -> Node2D:
	if has_target:
		return targets[0]
	return null


func get_closest_target_to_end() -> Node2D:
	if not has_target:
		return null
	
	var closest : Node2D = targets[0]
	
	for ctarget in targets:
		if ctarget.is_dead or ctarget == closest:
			continue
		
		if ctarget.get_remaining_path_waypoint_count() < closest.get_remaining_path_waypoint_count():
			closest = ctarget
	
	return closest


func _enable_tower() -> void:
	super()
	behaviour_tree.enable()


func _set_is_placing(value : bool) -> void:
	super(value)
	if is_placing:
		behaviour_tree.disable()
