extends Node2D

## Every enemy that comes as an elite: its own frames (left) and Elite.get_elite_frames (right), walking.
## Run this scene from the editor (Run Current Scene) to look at the elite art in the engine.

const ENEMY_PATH_FORMAT : String = "res://scenes/unit/enemy/enemies/%s.tscn"
const SPRITE_NODE : String = "AnimatedSprite2D"
const ENEMIES : Array[String] = ["armored_knight", "soldier", "sapper", "cavalry", "archer", "scout", "wizard", "priest",
	"assault_dog", "giant_eagle", "giant_wasp", "fastswampling", "leaper_frog", "swampling", "swbeefling", "leechling",
	"plaguepig", "bloater"]
const COLUMNS : int = 6
const CELL : Vector2 = Vector2(104, 112)
const BACKGROUND : Color = Color("439148")


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND)
	for i in ENEMIES.size():
		var origin : Vector2 = Vector2(i % COLUMNS, i / COLUMNS) * CELL + Vector2(8, 8)
		var enemy : Node = load(ENEMY_PATH_FORMAT % ENEMIES[i]).instantiate()
		var source : AnimatedSprite2D = enemy.get_node(SPRITE_NODE)
		var frames : SpriteFrames = source.sprite_frames
		enemy.free()
		_add_sprite(frames, origin + Vector2(24, 64))
		_add_sprite(Elite.get_elite_frames(frames), origin + Vector2(72, 64))
		var label : Label = Label.new()
		label.text = ENEMIES[i].replace("_", " ")
		label.position = origin
		add_child(label)


func _add_sprite(frames : SpriteFrames, at : Vector2) -> void:
	var sprite : AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.position = at
	add_child(sprite)
	sprite.play(GlobalAnimationNames.WALK_ANIMATION if frames.has_animation(GlobalAnimationNames.WALK_ANIMATION) else GlobalAnimationNames.IDLE_ANIMATION)
