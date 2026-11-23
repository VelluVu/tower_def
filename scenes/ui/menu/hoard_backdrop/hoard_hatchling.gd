class_name HoardHatchling
extends AnimatedSprite2D


## A drakeling fresh out of its egg on the title screen: hops down from the pile, then wanders the courtyard,
## rests and puffs its element's breath, until HoardBackdrop sends it flying off. Positions are in art pixels.
signal flown_off(hatchling : HoardHatchling)

enum State { HOP, REST, WALK, PUFF, FLY }

## Its feet in the 26x22 frame, facing right; facing left mirrors the frame, so the feet are FRAME_WIDTH - x.
const FOOT : Vector2 = Vector2(11, 20)
const FRAME_WIDTH : float = 26.0
const WALK_SPEED : float = 14.0
const HOP_TIME : float = 0.9
const HOP_HEIGHT : float = 18.0
const FLY_SPEED : Vector2 = Vector2(34.0, -46.0)
## Gone once this far above the top of the scene.
const FLOWN_OFF_Y : float = -30.0
const REST_TIME_MIN : float = 0.8
const REST_TIME_MAX : float = 3.0
const PUFF_CHANCE : float = 0.3
const HOP_Z_INDEX : int = 2

var state : State = State.REST
## Its feet, unrounded; the node itself always sits on whole art pixels.
var spot : Vector2 = Vector2.ZERO
var target : Vector2 = Vector2.ZERO
## Asked for the next place to walk to, given where it stands: (Vector2) -> Vector2.
var pick_target : Callable

var _hop_from : Vector2 = Vector2.ZERO
var _hop_time : float = 0.0
var _rest_time : float = 0.0
var _fly_direction : float = 1.0


func setup(frames : SpriteFrames, start : Vector2, target_picker : Callable) -> void:
	sprite_frames = frames
	centered = false
	pick_target = target_picker
	spot = start
	_face(1.0)
	_place()
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)


## Jumps from the egg down to the courtyard floor.
func hop_to(landing : Vector2) -> void:
	state = State.HOP
	_hop_from = spot
	_hop_time = 0.0
	target = landing
	z_index = HOP_Z_INDEX
	_face(signf(landing.x - spot.x))
	play(GlobalAnimationNames.HOP_ANIMATION)


func fly_off() -> void:
	state = State.FLY
	z_index = HOP_Z_INDEX
	#away from the middle of the scene, the shorter way out
	_fly_direction = 1.0 if spot.x >= HoardBackdrop.ART_SIZE.x * 0.6 else -1.0
	_face(_fly_direction)
	play(GlobalAnimationNames.FLY_ANIMATION)


func _process(delta : float) -> void:
	match state:
		State.HOP:
			_hop_time += delta
			var t : float = minf(_hop_time / HOP_TIME, 1.0)
			spot = _hop_from.lerp(target, t) + Vector2(0.0, -4.0 * HOP_HEIGHT * t * (1.0 - t))
			if t >= 1.0:
				z_index = 0
				_rest()
		State.REST:
			_rest_time -= delta
			if _rest_time <= 0.0:
				_walk()
		State.WALK:
			var to_target : Vector2 = target - spot
			var step : float = WALK_SPEED * delta
			if to_target.length() <= step:
				spot = target
				_rest()
			else:
				spot += to_target.normalized() * step
		State.FLY:
			spot += Vector2(FLY_SPEED.x * _fly_direction, FLY_SPEED.y) * delta
			if spot.y < FLOWN_OFF_Y:
				flown_off.emit(self)
				queue_free()
				return
	_place()


func _rest() -> void:
	state = State.REST
	_rest_time = randf_range(REST_TIME_MIN, REST_TIME_MAX)
	if randf() < PUFF_CHANCE:
		state = State.PUFF
		play(GlobalAnimationNames.PUFF_ANIMATION)
	else:
		play(GlobalAnimationNames.IDLE_ANIMATION)


func _walk() -> void:
	target = pick_target.call(spot) if pick_target.is_valid() else spot
	if target.distance_to(spot) < 2.0:
		_rest()
		return
	state = State.WALK
	_face(signf(target.x - spot.x))
	play(GlobalAnimationNames.WALK_ANIMATION)


func _on_animation_finished() -> void:
	if state == State.PUFF:
		state = State.REST
		play(GlobalAnimationNames.IDLE_ANIMATION)


func _face(direction : float) -> void:
	if direction == 0.0:
		return
	flip_h = direction < 0.0
	offset = -Vector2(FRAME_WIDTH - FOOT.x if flip_h else FOOT.x, FOOT.y)


func _place() -> void:
	position = spot.round()
