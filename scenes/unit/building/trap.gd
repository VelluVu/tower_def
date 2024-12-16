class_name Trap
extends Building


const RANGE_AREA_OBJECT_NULL_ERROR_MESSAGE : String = "NO RANGE AREA ON TOWER, UNABLE FIND TARGETS!"

@onready var range_area : Area2D = $RangeArea 
@onready var area_shape : CollisionShape2D = $RangeArea/CollisionShape2D

var targets : Array[Node2D]


func _ready() -> void:
	super()
	
	var stat : Stat = stats.get_stat(Utils.StatType.AttackRange)
	
	if not stat.changed.is_connected(_on_attack_range_stat_changed):
		stat.changed.connect(_on_attack_range_stat_changed)
		
	_on_attack_range_stat_changed(stat)
	
	if not GameSignals.enemy_destroyed.is_connected(_on_enemy_destroyed):
		GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	
	if range_area == null:
		push_warning(RANGE_AREA_OBJECT_NULL_ERROR_MESSAGE)
	
	if not range_area.body_entered.is_connected(_on_range_area_body_entered):
		range_area.body_entered.connect(_on_range_area_body_entered)
		
	if not range_area.body_exited.is_connected(_on_range_area_body_exited):
		range_area.body_exited.connect(_on_range_area_body_exited)
	
	if not skill.is_ready_signal.is_connected(_on_trap_ready):
		skill.is_ready_signal.connect(_on_trap_ready)
	
	if not animation_control.animation_finished.is_connected(_on_animation_finished):
		animation_control.animation_finished.connect(_on_animation_finished)


func _on_trap_ready(is_ready : bool) -> void:
	if targets.is_empty():
		return
	
	if is_ready:
		skill.use(targets[0])


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if targets.has(enemy):
		targets.erase(enemy)


func _on_range_area_body_entered(body: Node2D) -> void:
	if not targets.has(body):
		targets.append(body)
		
		if skill.is_ready:
			skill.use(body)


func _on_range_area_body_exited(body: Node2D) -> void:
	if targets.has(body):
		targets.erase(body)


func _on_attack_range_stat_changed(_stat : Stat) -> void:
	print(_stat.name, " changed to ", str(_stat.value))
	area_shape.shape.radius = radius


func _on_animation_finished() -> void:
	if animation_control.animation == GlobalAnimationNames.ATTACK_ANIMATION:
		animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)


func _get_radius() -> float:
	return stats.get_stat_value(Utils.StatType.AttackRange) * Utils.TILE_SIZE - Utils.TILE_SIZE * 0.5
