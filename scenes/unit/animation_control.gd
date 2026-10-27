class_name AnimationControl
extends AnimatedSprite2D


const FLASH_PARAMETER : StringName = &"flash"
const NO_FLASH_MATERIAL_WARNING : String = " has no unit sprite material, unable to play the hit flash"
#full flash, then half, then off: a hit during the half step shows as a new flash
const FLASH_STEPS : Array[float] = [1.0, 0.5, 0.0]

## Seconds the hit flash lasts, split evenly between its steps.
@export var flash_duration : float = 0.1

var flash_tween : Tween = null

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


func play_hit_animation() -> void:
	var shader_material : ShaderMaterial = material as ShaderMaterial

	if shader_material == null:
		push_warning(actor.name, NO_FLASH_MATERIAL_WARNING)
		return

	#every hit restarts the flash at full, also one landing while the last flash is still on
	if flash_tween != null:
		flash_tween.kill()

	shader_material.set_shader_parameter(FLASH_PARAMETER, FLASH_STEPS[0])
	flash_tween = create_tween()
	var step_time : float = flash_duration / (FLASH_STEPS.size() - 1)

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
func _process(_delta : float) -> void:
	position = pixel_snap_position + actor.global_position.round() - actor.global_position


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
