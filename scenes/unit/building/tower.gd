class_name Tower
extends Building


const RANGE_AREA_OBJECT_NULL_ERROR_MESSAGE : String = "NO RANGE AREA ON TOWER, UNABLE FIND TARGETS!"
#how a silenced tower looks
const SILENCED_MODULATE : Color = Color(0.55, 0.55, 0.7)

@onready var range_area : Area2D = $RangeArea
@onready var area_shape : CollisionShape2D = $RangeArea/CollisionShape2D

## Flyers count as targets from the start; off for the Nova.
@export var can_hit_air : bool = true
## Flyers count from this tier on (0 = never by tier): the Nova at T2. Every tower hits flyers in the end or has an
## upgrade for it (the user, 2026-11-20: T2, since at T1 three Novas carried whole flyer levels; traps get Bird
## Catcher at Leopard T2).
@export var air_from_tier : int = 0
## Enemies closer than this many tiles are out of its reach (the Mortar cannot lob onto its own feet).
@export var min_range_tiles : float = 0.0

var hits_air : bool :
	get:
		return can_hit_air or (air_from_tier > 0 and evolve_tree != null and evolve_tree.tier >= air_from_tier)

var targets : Array[Node2D]
var target : Node2D = null
#which enemy in range it shoots (the selection panel cycles it); only for towers that pick targets
@export var target_tactic : Utils.TargetTactic = Utils.TargetTactic.First

## Bolter- and Beamer-like towers pick one target; a Nova bursts around itself and traps wait to be stepped on.
var can_choose_target : bool :
	get:
		return skill != null and skill.skill_type in [Utils.SkillType.Projectile, Utils.SkillType.Beaming, Utils.SkillType.Artillery, Utils.SkillType.Breath, Utils.SkillType.Sniper, Utils.SkillType.Harpoon]
## Area towers reach a submerged bog lurker (Submerged); bolts, beams and harpoons do not.
var reaches_submerged : bool :
	get:
		return skill != null and (skill.skill_type & (Utils.SkillType.Area | Utils.SkillType.Artillery | Utils.SkillType.Breath | Utils.SkillType.Blast)) != 0
#a screech: the tower sees no targets until the timer ends
var silence_timer : CustomTimer = null

var is_silenced : bool :
	get:
		return silence_timer != null and not silence_timer.is_stopped()

var has_target : bool :
	get:
		return not targets.is_empty() and not is_silenced


func _ready() -> void:
	super()
	#the scene's shape is shared by every instance: without a copy one tower's range resizes them all
	area_shape.shape = area_shape.shape.duplicate()
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

	if air_from_tier > 0 and evolve_tree != null and not evolve_tree.tier_changed.is_connected(_on_tier_changed):
		evolve_tree.tier_changed.connect(_on_tier_changed)


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
	if not hits_air and body is Enemy and body.is_flying:
		return
	targets.append(body)


#the flyers already in range become targets the moment the tier lets the tower reach them
func _on_tier_changed(_tier : int) -> void:
	if not hits_air:
		return
	for body in range_area.get_overlapping_bodies():
		if body is Enemy and body.is_flying and not targets.has(body):
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


## The target its tactic picks among the enemies in range (First when it cannot choose).
func get_tactic_target() -> Node2D:
	if not has_target:
		return null
	var candidates : Array[Node2D] = targets if min_range_tiles <= 0.0 else get_targets_beyond_min_range()
	return TargetPicker.pick(target_tactic if can_choose_target else Utils.TargetTactic.First, candidates, global_position, reaches_submerged)


## The targets in range that are not too close to fire at.
func get_targets_beyond_min_range() -> Array[Node2D]:
	var min_distance : float = min_range_tiles * Utils.TILE_SIZE
	var beyond : Array[Node2D] = []
	beyond.assign(targets.filter(func(candidate) -> bool:
		return is_instance_valid(candidate) and candidate.global_position.distance_to(global_position) >= min_distance))
	return beyond


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
	beehave_tree.enable()


func _set_is_placing(value : bool) -> void:
	super(value)
	if is_placing:
		beehave_tree.disable()
