class_name EnemyMarks
extends Node2D

## The marks on an enemy (the Spotter, 2026-11-24): a marked enemy takes a share more of that element's damage from
## every tower for SECONDS. One mark per element; a new mark renews the time and keeps the stronger share. Made on
## the enemy by the first mark (EnemyMarks.mark), drawn as corner brackets in the element's colour over its body.

const NODE_NAME : String = "Marks"
const SECONDS : float = 3.0
## Half the bracket box's size around the body centre, and each corner's arm length, in pixels.
const BOX_HALF : int = 7
const ARM : int = 3
const COLORS : Dictionary[Utils.DamageType, Color] = {
	Utils.DamageType.Physical: Color(0.75, 0.8, 0.86),
	Utils.DamageType.Fire: Color(0.97, 0.46, 0.13),
	Utils.DamageType.Frost: Color(0.17, 0.91, 0.96),
	Utils.DamageType.Poison: Color(0.71, 0.84, 0.24),
}

var enemy : Enemy = null
#damage type -> [share, seconds left]
var marks : Dictionary = {}


## Marks the enemy for this element; returns its marks node.
static func mark(target : Enemy, damage_type : Utils.DamageType, share : float, seconds : float = SECONDS) -> EnemyMarks:
	var node : EnemyMarks = target.get_node_or_null(NodePath(NODE_NAME)) as EnemyMarks
	if node == null:
		node = EnemyMarks.new()
		node.name = NODE_NAME
		node.enemy = target
		node.z_index = 1
		target.add_child(node)
	var old : Array = node.marks.get(damage_type, [0.0, 0.0])
	node.marks[damage_type] = [maxf(share, float(old[0])), maxf(seconds, float(old[1]))]
	node.queue_redraw()
	return node


## The extra share of damage of this type the enemy takes from its marks (0 without one).
static func get_bonus(target : Enemy, damage_type : Utils.DamageType) -> float:
	var node : EnemyMarks = target.get_node_or_null(NodePath(NODE_NAME)) as EnemyMarks
	if node == null:
		return 0.0
	return float(node.marks.get(damage_type, [0.0, 0.0])[0])


func _process(delta : float) -> void:
	if marks.is_empty():
		return
	var time_scale : float = Utils.game_control.time_scale if Utils.game_control != null else 1.0
	for damage_type in marks.keys():
		marks[damage_type][1] -= delta * time_scale
		if marks[damage_type][1] <= 0.0:
			marks.erase(damage_type)
	if is_instance_valid(enemy):
		position = (enemy.body_center - enemy.global_position).round()
	queue_redraw()


#four corner brackets on whole pixels, in the newest-coloured mark (the strongest share)
func _draw() -> void:
	if marks.is_empty():
		return
	var best_type : Utils.DamageType = Utils.DamageType.Physical
	var best_share : float = -1.0
	for damage_type in marks:
		if float(marks[damage_type][0]) > best_share:
			best_share = marks[damage_type][0]
			best_type = damage_type
	var color : Color = COLORS.get(best_type, COLORS[Utils.DamageType.Physical])
	for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var at : Vector2 = Vector2(corner * BOX_HALF)
		draw_rect(Rect2(at.x - (0 if corner.x < 0 else ARM - 1), at.y, ARM, 1), color)
		draw_rect(Rect2(at.x, at.y - (0 if corner.y < 0 else ARM - 1), 1, ARM), color)
