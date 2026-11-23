class_name BossIntro
extends Control


## A card that sweeps across when a boss arrives (2026-11-23): the boss's own walk animation in a glowing
## window, its name and its title (Enemy.boss_title). The card art is per boss (tools/art/boss_cards.py,
## 150x48 at 2x, named after the boss's scene file). The game keeps running underneath.
const CARD_PATH : String = "res://assets/art/ui/boss_cards/boss_card_%s.png"
const FALLBACK_CARD : String = "dragonslayer"
const ART_SCALE : int = 2
## The portrait window's middle on the card, in screen pixels.
const PORTRAIT_AT : Vector2 = Vector2(48, 50)
const NAME_AT : Vector2 = Vector2(108, 26)
const TITLE_AT : Vector2 = Vector2(108, 62)
const TITLE_COLOR : Color = Color("c0cbdc")
const NAME_VARIATION : StringName = &"TitleLabel"
const CARD_TOP : float = 64.0
const SLIDE_IN_TIME : float = 0.35
const HOLD_TIME : float = 2.6
const SLIDE_OUT_TIME : float = 0.3

var card : TextureRect = null
var portrait : AnimatedSprite2D = null
var name_label : Label = null
var title_label : Label = null
var tween : Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	#a level-up menu pauses the tree; the card still leaves
	process_mode = Node.PROCESS_MODE_ALWAYS
	card = TextureRect.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.visible = false
	add_child(card)
	portrait = AnimatedSprite2D.new()
	portrait.scale = Vector2.ONE * ART_SCALE
	portrait.position = PORTRAIT_AT
	card.add_child(portrait)
	name_label = Label.new()
	name_label.theme_type_variation = NAME_VARIATION
	name_label.position = NAME_AT
	card.add_child(name_label)
	title_label = Label.new()
	title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	title_label.position = TITLE_AT
	card.add_child(title_label)
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)


func _on_enemy_spawned(enemy : Enemy) -> void:
	if not enemy.is_boss or card.visible:
		return
	var boss_name : String = enemy.scene_file_path.get_file().get_basename()
	var path : String = CARD_PATH % boss_name
	card.texture = load(path if ResourceLoader.exists(path) else CARD_PATH % FALLBACK_CARD)
	card.size = card.texture.get_size() * ART_SCALE
	name_label.text = enemy.selectable.get_display_name()
	title_label.text = enemy.boss_title
	_show_portrait(enemy)
	_sweep()


## The boss's own frames, walking.
func _show_portrait(enemy : Enemy) -> void:
	portrait.sprite_frames = null
	for child in enemy.get_children():
		if child is AnimatedSprite2D:
			portrait.sprite_frames = (child as AnimatedSprite2D).sprite_frames
			break
	if portrait.sprite_frames == null:
		return
	var walk : StringName = GlobalAnimationNames.WALK_ANIMATION
	portrait.play(walk if portrait.sprite_frames.has_animation(walk) else StringName(GlobalAnimationNames.IDLE_ANIMATION))


## In from the left, a moment in the middle, out to the right, on whole pixels.
func _sweep() -> void:
	var screen : Vector2 = get_viewport_rect().size
	var middle : float = roundf((screen.x - card.size.x) / 2.0)
	card.position = Vector2(-card.size.x, CARD_TOP)
	card.visible = true
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_method(_place_card, -card.size.x, middle, SLIDE_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_method(_place_card, middle, screen.x, SLIDE_OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hide_card)


func _place_card(x : float) -> void:
	card.position.x = roundf(x)


func _hide_card() -> void:
	card.visible = false
	portrait.stop()
