class_name EndVignette
extends PanelContainer


## The framed picture at the top of the level end screens (2026-11-23): on a win the hoard hall with three
## drakelings jumping for joy under a rain of gold, on a loss the dark hall with the hoard carried off and a
## drakeling sitting by a cracked egg while smoke drifts from the gate. Art from tools/art/end_vignettes.py
## (160x60, drawn at 2x); the hatchlings are the title screen's.
enum Kind { WIN, LOSE }

const WIN_PICTURE : Texture2D = preload("res://assets/art/ui/end_screens/end_win.png")
const LOSE_PICTURE : Texture2D = preload("res://assets/art/ui/end_screens/end_lose.png")
const COIN_FRAMES : SpriteFrames = preload("res://scenes/ui/end_vignette/frames/end_coin_frames.tres")
const SMOKE_FRAMES : SpriteFrames = preload("res://scenes/ui/end_vignette/frames/end_smoke_frames.tres")
const HATCHLING_FRAMES : String = "res://scenes/ui/menu/hoard_backdrop/frames/hatchling_%s_frames.tres"
const ELEMENTS : Array[String] = ["mint", "fire", "frost", "poison"]
const ART_SIZE : Vector2 = Vector2(160, 60)
## Whole steps, so every art pixel stays square.
const ART_SCALE : int = 2
const FRAME_STYLE : StringName = &"InsetPanelContainer"

## Win: where the cheering drakelings stand (their feet) and which way they face, towards the pile.
const CHEER_SPOTS : Array[Vector2] = [Vector2(14, 57), Vector2(33, 58), Vector2(141, 57)]
const CHEER_FACING : Array[float] = [1.0, 1.0, -1.0]
## The title's torch flames on the two sconces (their top left; the lose picture's torches are out).
const TORCH_FRAMES : SpriteFrames = preload("res://scenes/ui/menu/hoard_backdrop/frames/hoard_torch_frames.tres")
const TORCH_SPOTS : Array[Vector2] = [Vector2(17, 9), Vector2(137, 9)]
const JUMP_HEIGHT : float = 6.0
const JUMPS_PER_SECOND : float = 1.6
## Off the ground by more than this, a jumper shows its wings-up frame.
const AIRBORNE : float = 1.0
const COIN_INTERVAL : float = 0.09
const COIN_GRAVITY : float = 140.0
const COIN_START_SPEED : float = 15.0
## Coins land somewhere on the floor strip and lie there a moment.
const COIN_FLOOR_MIN : float = 50.0
const COIN_FLOOR_MAX : float = 59.0
const COIN_REST_TIME : float = 0.5

## Lose: the drakeling sits by the cracked egg; smoke rises from the gate.
const SAD_SPOT : Vector2 = Vector2(86, 58)
const SMOKE_INTERVAL : float = 0.5
const SMOKE_AREA : Rect2 = Rect2(60, 40, 40, 8)
const SMOKE_RISE : float = 9.0
const SMOKE_DRIFT : float = 3.0

var kind : Kind = Kind.WIN
var stage : Node2D = null
var jumpers : Array[HoardHatchling] = []

var _time : float = 0.0
var _spawn_timer : float = 0.0
var _jump_phases : Array[float] = []
## Falling coins and rising smoke: {"node": AnimatedSprite2D, "velocity": Vector2, "floor": float, "rest": float}
var _bits : Array[Dictionary] = []


static func build(picture_kind : Kind) -> EndVignette:
	var vignette : EndVignette = EndVignette.new()
	vignette.kind = picture_kind
	return vignette


func _ready() -> void:
	theme_type_variation = FRAME_STYLE
	#the end screens may stop the tree; the picture keeps moving
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view : Control = Control.new()
	view.custom_minimum_size = ART_SIZE * ART_SCALE
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	stage = Node2D.new()
	stage.scale = Vector2.ONE * ART_SCALE
	view.add_child(stage)

	var picture : Sprite2D = Sprite2D.new()
	picture.texture = WIN_PICTURE if kind == Kind.WIN else LOSE_PICTURE
	picture.centered = false
	stage.add_child(picture)
	if kind == Kind.WIN:
		for spot in TORCH_SPOTS:
			var torch : AnimatedSprite2D = _add_bit(TORCH_FRAMES, spot)
			torch.frame = randi() % TORCH_FRAMES.get_frame_count(GlobalAnimationNames.IDLE_ANIMATION)
		var elements : Array[String] = ELEMENTS.duplicate()
		elements.shuffle()
		for i in CHEER_SPOTS.size():
			jumpers.append(_add_hatchling(elements[i], CHEER_SPOTS[i], CHEER_FACING[i], GlobalAnimationNames.HOP_ANIMATION))
			_jump_phases.append(randf())
	else:
		_add_hatchling(ELEMENTS.pick_random(), SAD_SPOT, 1.0, GlobalAnimationNames.SAD_ANIMATION).play()


func _process(delta : float) -> void:
	_time += delta
	_spawn_timer -= delta
	if kind == Kind.WIN:
		_jump()
		if _spawn_timer <= 0.0:
			_spawn_timer = COIN_INTERVAL
			_drop_coin()
	elif _spawn_timer <= 0.0:
		_spawn_timer = SMOKE_INTERVAL
		_puff_smoke()
	_move_bits(delta)


func _add_hatchling(element : String, feet : Vector2, facing : float, animation_name : StringName) -> HoardHatchling:
	var hatchling : HoardHatchling = HoardHatchling.new()
	hatchling.setup(load(HATCHLING_FRAMES % element) as SpriteFrames, feet, Callable())
	hatchling.set_process(false)
	hatchling.face(facing)
	hatchling.animation = animation_name
	stage.add_child(hatchling)
	return hatchling


## Each jumper hops on its own beat: crouched on the ground, wings up in the air.
func _jump() -> void:
	for i in jumpers.size():
		var beat : float = fposmod(_time * JUMPS_PER_SECOND + _jump_phases[i], 1.0)
		var height : float = JUMP_HEIGHT * sin(beat * PI)
		jumpers[i].position = (CHEER_SPOTS[i] - Vector2(0.0, height)).round()
		jumpers[i].frame = 1 if height > AIRBORNE else 0


func _drop_coin() -> void:
	var coin : AnimatedSprite2D = _add_bit(COIN_FRAMES, Vector2(randf_range(0.0, ART_SIZE.x), -4.0))
	_bits.append({"node": coin, "velocity": Vector2(0.0, COIN_START_SPEED), "floor": randf_range(COIN_FLOOR_MIN, COIN_FLOOR_MAX), "rest": COIN_REST_TIME})


func _puff_smoke() -> void:
	var spot : Vector2 = SMOKE_AREA.position + Vector2(randf() * SMOKE_AREA.size.x, randf() * SMOKE_AREA.size.y)
	var smoke : AnimatedSprite2D = _add_bit(SMOKE_FRAMES, spot)
	smoke.animation_looped.connect(smoke.queue_free)
	_bits.append({"node": smoke, "velocity": Vector2(randf_range(-SMOKE_DRIFT, SMOKE_DRIFT), -SMOKE_RISE), "floor": INF, "rest": 0.0})


func _add_bit(frames : SpriteFrames, spot : Vector2) -> AnimatedSprite2D:
	var bit : AnimatedSprite2D = AnimatedSprite2D.new()
	bit.sprite_frames = frames
	bit.centered = false
	bit.set_meta(&"spot", spot)
	bit.position = spot.round()
	stage.add_child(bit)
	bit.play(GlobalAnimationNames.IDLE_ANIMATION)
	return bit


func _move_bits(delta : float) -> void:
	for i in range(_bits.size() - 1, -1, -1):
		var bit : Dictionary = _bits[i]
		var node : AnimatedSprite2D = bit.node
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_bits.remove_at(i)
			continue
		var spot : Vector2 = node.get_meta(&"spot")
		if spot.y >= bit.floor:
			#a landed coin lies flat for a moment
			node.stop()
			node.frame = 0
			bit.rest -= delta
			if bit.rest <= 0.0:
				node.queue_free()
				_bits.remove_at(i)
			continue
		if bit.floor != INF:
			bit.velocity.y += COIN_GRAVITY * delta
		spot += bit.velocity * delta
		node.set_meta(&"spot", spot)
		node.position = spot.round()
