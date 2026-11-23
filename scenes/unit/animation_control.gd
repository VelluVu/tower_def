class_name AnimationControl
extends AnimatedSprite2D


const FLASH_PARAMETER : StringName = &"flash"
const NO_FLASH_MATERIAL_WARNING : String = " has no unit sprite material, unable to play the hit flash"
#full flash, then half, then off: a hit during the half step shows as a new flash
const FLASH_STEPS : Array[float] = [1.0, 0.5, 0.0]
const HIT_COLOR_PARAMETER : StringName = &"hit_color"
#a hit enemy's sprite jumps this many world pixels backwards for a moment (whole pixels, see _process)
const FLINCH_PIXELS : float = 1.0

## Seconds the hit flash lasts, split evenly between its steps.
@export var flash_duration : float = 0.1
## Game seconds an enemy's flinch lasts.
@export var flinch_time : float = 0.06
## Game seconds after a flinch before the next one: a beam's ticks would otherwise make the sprite shake.
@export var flinch_cooldown : float = 0.25

var flash_tween : Tween = null
#the material's own hit colour, put back by every hit flash after a coloured one
var base_hit_color : Variant = null

var actor : Node2D :
	get:
		if actor == null:
			actor = get_parent()
		return actor

#stored time scale values
var is_time_altered : bool = false :
	get:
		return current_time_scale != 1.0
var current_time_scale : float = 1.0

#the wanted animation duration in seconds, 0.0 == original animation length
var current_wanted_playtime : float = 0.0
#the sprite's position in its scene; the pixel snap moves it less than a pixel around this
var pixel_snap_position : Vector2 = Vector2.ZERO
var flinch_left : float = 0.0
var flinch_cooldown_left : float = 0.0


func play_animation(animation_name : String, wanted_play_time : float = 0.0, is_no_slowing : bool = false) -> void:
	if not sprite_frames.has_animation(animation_name):
		push_warning(name, " has no animation with name: ", animation_name)
		return
	
	current_wanted_playtime = wanted_play_time
	
	#if looping animation is ongoing, then only alter the animation speed
	if animation == animation_name:
		if sprite_frames.get_animation_loop(animation_name):
			if is_playing():
				_alter_current_animation_speed(is_no_slowing)
				return
	
	#one shot animation is started before altering
	play(animation_name)
	_alter_current_animation_speed(is_no_slowing)


## The hit flash; with flinch, an enemy also recoils a pixel (direct hits, not burn or poison ticks).
func play_hit_animation(flinch : bool = false) -> void:
	play_flash(null)
	if flinch and actor is Enemy and flinch_cooldown_left <= 0.0:
		flinch_left = flinch_time
		flinch_cooldown_left = flinch_cooldown


## The hit flash in another colour and length (a building going up flashes white); null is the hit colour.
func play_flash(color : Variant, duration : float = flash_duration) -> void:
	var shader_material : ShaderMaterial = material as ShaderMaterial

	if shader_material == null:
		push_warning(actor.name, NO_FLASH_MATERIAL_WARNING)
		return

	if base_hit_color == null:
		base_hit_color = shader_material.get_shader_parameter(HIT_COLOR_PARAMETER)
	shader_material.set_shader_parameter(HIT_COLOR_PARAMETER, base_hit_color if color == null else color)

	#every hit restarts the flash at full, also one landing while the last flash is still on
	if flash_tween != null:
		flash_tween.kill()

	shader_material.set_shader_parameter(FLASH_PARAMETER, FLASH_STEPS[0])
	flash_tween = create_tween()
	var step_time : float = duration / (FLASH_STEPS.size() - 1)

	for step in FLASH_STEPS.slice(1):
		flash_tween.tween_interval(step_time)
		flash_tween.tween_callback(shader_material.set_shader_parameter.bind(FLASH_PARAMETER, step))


func is_current_animation_finished() -> bool:
	if is_playing():
		return sprite_frames.get_animation_loop(animation)
	return true


func flip(flip_direction : Vector2) -> void:
	var new_flip_state : bool = (flip_direction.x < 0.0)
	
	if new_flip_state == flip_h:
		return
		
	flip_h = new_flip_state


func _ready() -> void:
	#event from game control, when the time scale is changed
	if not GameSignals.time_scale_change.is_connected(_on_time_scale_change):
		GameSignals.time_scale_change.connect(_on_time_scale_change)

	#check the current time scale when this object is ready
	_on_time_scale_change(Utils.game_control.time_scale)


	#buildings stand on the grid; only moving units need the pixel snap
	pixel_snap_position = position
	set_process(actor is Enemy)


#the body moves in fractions of a pixel; the sprite is drawn on whole world pixels,
#so at 2x and 3x zoom a walking unit never sits half an art pixel off
#(position, not offset: Godot's own snap rounds the offset away)
func _process(delta : float) -> void:
	var game_delta : float = delta * current_time_scale
	flinch_cooldown_left = maxf(0.0, flinch_cooldown_left - game_delta)
	var recoil : Vector2 = Vector2.ZERO
	if flinch_left > 0.0:
		flinch_left -= game_delta
		#backwards: a sprite facing left (flip_h) jumps right
		recoil.x = FLINCH_PIXELS if flip_h else -FLINCH_PIXELS
	position = pixel_snap_position + recoil + actor.global_position.round() - actor.global_position


func _alter_current_animation_speed(no_slowing : bool = false) -> void:
	if not is_playing():
		return
	
	#if wanted play time is 0.0 we keep the time scale as it is
	if current_wanted_playtime <= 0.0:
		speed_scale = Utils.game_control.time_scale
		return
	
	var frames_count : int = sprite_frames.get_frame_count(animation)
	var animation_duration : float = 0
	var animation_fps : float = sprite_frames.get_animation_speed(animation)
	var current_playing_speed : float = abs(get_playing_speed())
	
	for n in range(frames_count):
		var absolute_frame_duration : float = sprite_frames.get_frame_duration(animation, n) / (animation_fps * current_playing_speed)
		animation_duration += absolute_frame_duration
	
	
	var scaler : float = 1 / (current_wanted_playtime / animation_duration)
	if no_slowing and scaler < 1.0:
		scaler = 1.0
	speed_scale = scaler * current_time_scale if scaler != 1.0 else speed_scale


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	_alter_current_animation_speed()
