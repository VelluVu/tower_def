class_name EnemyShot
extends Node2D

## A shot an enemy fires at a building (an arrow, a spell, a thrown rock): flies to where the target
## stood, in game time, along an optional arc, then calls landed. RangedShotAbility makes and aims it.

signal landed(shot : EnemyShot)

var target_position : Vector2 = Vector2.ZERO
var start_position : Vector2 = Vector2.ZERO
#pixels per second at 1x speed
var speed : float = 120.0
#pixels the arc rises at its middle; 0 = straight
var arc_height : float = 0.0
var rotates : bool = false
var frame_time : float = 0.08

var sprite : Sprite2D = null
var travelled : float = 0.0
var frame_timer : float = 0.0
var current_time_scale : float = 1.0


## texture: the shot's sheet, frames: its frames in a grid of hframes x vframes
func setup(texture : Texture2D, hframes : int, vframes : int, from : Vector2, to : Vector2) -> void:
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	start_position = from
	target_position = to
	global_position = from
	z_index = 1


func _ready() -> void:
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)


func _process(delta : float) -> void:
	var length : float = start_position.distance_to(target_position)
	travelled += speed * delta * current_time_scale
	var t : float = 1.0 if length <= 0.0 else minf(travelled / length, 1.0)
	var previous : Vector2 = global_position
	global_position = start_position.lerp(target_position, t) + Vector2(0.0, -arc_height * 4.0 * t * (1.0 - t))

	if rotates and global_position != previous:
		sprite.rotation = (global_position - previous).angle()

	frame_timer += delta * current_time_scale
	if frame_timer >= frame_time:
		frame_timer = 0.0
		sprite.frame = (sprite.frame + 1) % (sprite.hframes * sprite.vframes)

	if t >= 1.0:
		landed.emit(self)
		queue_free()


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
