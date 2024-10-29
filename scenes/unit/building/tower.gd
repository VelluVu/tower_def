class_name Tower
extends Building

#let the tower to be behaviour tree driven, and add features as components to allow reuse of this inherited class on other towers aswell.
#support behaviour tree functionality, functions for selecting enemy targets on range, cast projectile/spell etc...
#how to select targets in range without area2D in godot, or use circle area2d?

#basic shooting is added as component and basic bt tries to use it through this actor.
#for basic shooting create and add projectile as component, tween the projectile to hit the target 100% accuracy.
const IDLE_ANIMATION = "IDLE"
const ATTACK_ANIMATION = "ATTACK"

@onready var range_area : Area2D = $RangeArea 
@onready var area_shape : CollisionShape2D = $RangeArea/CollisionShape2D

@export var skill : TowerSkill

var targets : Array[Node2D]
var target : Node2D = null

var has_target : bool :
	get:
		return not targets.is_empty()

var behaviour_tree : BeehaveTree :
	get:
		if behaviour_tree == null:
			for child in get_children():
				if child is BeehaveTree:
					behaviour_tree = child
		return behaviour_tree


func _ready() -> void:
	super()
	area_shape.shape.radius = stats_manager.get_range_in_tiles()
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	
	if range_area == null:
		push_warning("NO RANGE AREA ON TOWER, UNABLE FIND TARGETS!")
	
	if not range_area.body_entered.is_connected(_on_range_area_body_entered):
		range_area.body_entered.connect(_on_range_area_body_entered)
		
	if not range_area.body_exited.is_connected(_on_range_area_body_exited):
		range_area.body_exited.connect(_on_range_area_body_exited)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if target == enemy:
		target = null
		
	if targets.has(enemy):
		targets.erase(enemy)


func _on_range_area_body_entered(body: Node2D) -> void:
	print(body.name, " entered range area")
	targets.append(body)


func _on_range_area_body_exited(body: Node2D) -> void:
	print(body.name, " left range area")
	if body == target:
		target = null
		
	targets.erase(body)


func _on_stats_changed() -> void:
	super()


func _on_stat_changed(stat_type, stat_value) -> void:
	print(str(Utils.StatType.keys()[stat_type]), " changed to ", str(stat_value))
	if stat_type == Utils.StatType.AttackRange:
		area_shape.shape.radius = Utils.TILE_SIZE * stats_manager.stats.attack_range


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
		if ctarget.point_path.size() <= closest.point_path.size():
			closest = ctarget
	
	return closest


func _enable_tower() -> void:
	super()
	behaviour_tree.enable()


func _set_is_placing(value : bool) -> void:
	super(value)
	if is_placing:
		behaviour_tree.disable()
