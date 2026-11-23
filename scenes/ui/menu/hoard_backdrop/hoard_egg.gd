class_name HoardEgg
extends AnimatedSprite2D


## One dragon egg on the title screen's hoard: it rocks a few times, cracks and hatches, then stays an empty
## shell until HoardBackdrop renews it. Art and frames from tools/art/hoard_backdrop.py.
signal hatched(egg : HoardEgg)

## Where the egg meets the coins in its 28x38 frame: the node's position is that spot on the pile.
const FOOT : Vector2 = Vector2(14, 36)
## Seconds to wait after each step of the hatching before the next one starts.
const STEP_PAUSES : Array[float] = [1.2, 1.6, 1.0, 0.5, 0.0]

var element : String = ""
var is_hatched : bool = false
var is_hatching : bool = false

var _steps : Array[String] = []
var _step : int = -1
var _wait : float = 0.0


func setup(frames : SpriteFrames, egg_element : String) -> void:
	sprite_frames = frames
	element = egg_element
	centered = false
	offset = -FOOT
	_steps = [GlobalAnimationNames.WOBBLE_ANIMATION, GlobalAnimationNames.WOBBLE_ANIMATION,
		GlobalAnimationNames.CRACK_ANIMATION, GlobalAnimationNames.WOBBLE_ANIMATION,
		GlobalAnimationNames.HATCH_ANIMATION]
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	renew()


func start_hatching() -> void:
	if is_hatched or is_hatching:
		return
	is_hatching = true
	_step = 0
	play(_steps[_step])


## A fresh egg again, after the hatchling has flown off.
func renew() -> void:
	is_hatched = false
	is_hatching = false
	_step = -1
	_wait = 0.0
	play(GlobalAnimationNames.IDLE_ANIMATION)


func _process(delta : float) -> void:
	if _wait <= 0.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		_step += 1
		play(_steps[_step])


func _on_animation_finished() -> void:
	if not is_hatching:
		return
	if animation == GlobalAnimationNames.HATCH_ANIMATION:
		is_hatching = false
		is_hatched = true
		play(GlobalAnimationNames.EMPTY_ANIMATION)
		hatched.emit(self)
		return
	#a pause of 0 still waits one frame, so the next step starts from _process
	_wait = maxf(STEP_PAUSES[_step], 0.001)
