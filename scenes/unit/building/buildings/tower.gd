class_name Tower
extends Building

#let the tower to be behaviour tree driven, and add features as components to allow reuse of this inherited class on other towers aswell.
#support behaviour tree functionality, functions for selecting enemy targets on range, cast projectile/spell etc...
#how to select targets in range without area2D in godot, or use circle area2d?

#basic shooting is added as component and basic bt tries to use it through this actor.
#for basic shooting create and add projectile as component, tween the projectile to hit the target 100% accuracy.

@onready var range_area : Area2D = $RangeArea 
@onready var area_shape : CollisionShape2D = $RangeArea/CollisionShape2D
@export var skill : TowerSkill

var targets : Array[Node2D]

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
	area_shape.shape.radius = Utils.TILE_SIZE * stats_manager.stats.attack_range
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if targets.has(enemy):
		targets.erase(enemy)


func _on_range_area_body_entered(body: Node2D) -> void:
	targets.append(body)


func _on_range_area_body_exited(body: Node2D) -> void:
	targets.erase(body)


func _on_stats_changed() -> void:
	super()


func _on_stat_changed(stat_type, stat_value) -> void:
	print(str(Utils.StatType.keys()[stat_type]), " changed to ", str(stat_value))
	if stat_type == Utils.StatType.AttackRange:
		area_shape.shape.radius = Utils.TILE_SIZE * stats_manager.stats.attack_range


func get_first_target() -> Node2D:
	return targets[0]


func _enable_tower() -> void:
	super()
	behaviour_tree.enable()


func _set_is_placing(value : bool) -> void:
	super(value)
	if is_placing:
		behaviour_tree.disable()
