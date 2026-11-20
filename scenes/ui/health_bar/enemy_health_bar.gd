class_name EnemyHealthBar
extends Node2D

## A small health bar over an enemy's head (the user's playtest, 2026-10-28: "small, over the enemy's head", with an
## Options toggle). Shown once the enemy is hurt; hidden at full health, while dead, burrowed or hidden in a
## sandstorm, and when the Health bars option is off. Bosses have the big boss bar instead. Attached by Level.

const NODE_NAME : String = "HealthBar"
const HEIGHT : int = 2
const MIN_WIDTH : int = 8
const MAX_WIDTH : int = 18
#the bar is this much narrower than the sprite's canvas (the canvas has empty space around the body)
const SPRITE_MARGIN : int = 6
#from the PopUpSpot, so it sits just over the head
const OFFSET : Vector2 = Vector2(0, -1)
#over the units and flyers (sprite z 1), under the edge fog (z 20)
const BAR_Z_INDEX : int = 10
#Endesga 32: a dark frame, an empty track, the red fill with a lighter top row
const FRAME_COLOR : Color = Color("181425")
const EMPTY_COLOR : Color = Color("3a4466")
const FILL_COLOR : Color = Color("a22633")
const FILL_LIGHT_COLOR : Color = Color("e43b44")

var enemy : Enemy = null
var width : int = 12
var shown_ratio : float = -1.0
var is_enabled : bool = true


## Gives the enemy its bar once (bosses get none: the boss bar shows them).
static func attach(target : Enemy) -> void:
	if target.is_boss or target.get_node_or_null(NODE_NAME) != null:
		return
	var bar : EnemyHealthBar = EnemyHealthBar.new()
	bar.name = NODE_NAME
	bar.enemy = target
	target.add_child(bar)


func _ready() -> void:
	#its own transform: placed on whole pixels each frame, like the sprites
	top_level = true
	z_as_relative = false
	z_index = BAR_Z_INDEX
	width = _width_from_sprite()
	is_enabled = SettingsManager.get_option(SettingsManager.OPTION_HEALTH_BARS)
	if not SettingsManager.option_changed.is_connected(_on_option_changed):
		SettingsManager.option_changed.connect(_on_option_changed)
	_refresh()


func _process(_delta : float) -> void:
	_refresh()


func _refresh() -> void:
	var ratio : float = _health_ratio()
	visible = ratio >= 0.0
	if not visible:
		return
	global_position = (enemy.pop_up_spot.global_position + OFFSET).round()
	if not is_equal_approx(ratio, shown_ratio):
		shown_ratio = ratio
		queue_redraw()


## The share of health left, or -1 when the bar should not show.
func _health_ratio() -> float:
	if not is_enabled or not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.is_burrowed \
			or enemy.is_concealed or not enemy.visible:
		return -1.0
	var max_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
	var health : float = enemy.stats.get_stat_value(Utils.StatType.Health)
	if max_health <= 0.0 or health >= max_health - 0.01:
		return -1.0
	return clampf(health / max_health, 0.0, 1.0)


func _draw() -> void:
	#whole pixels: an odd width leans one pixel right
	@warning_ignore("integer_division")
	var left : int = -width / 2
	draw_rect(Rect2(left - 1, -1, width + 2, HEIGHT + 2), FRAME_COLOR)
	draw_rect(Rect2(left, 0, width, HEIGHT), EMPTY_COLOR)
	#at least one pixel while it lives, so a nearly dead enemy still shows red
	var fill : int = maxi(roundi(width * shown_ratio), 1 if shown_ratio > 0.0 else 0)
	if fill > 0:
		draw_rect(Rect2(left, 0, fill, HEIGHT), FILL_COLOR)
		draw_rect(Rect2(left, 0, fill, 1), FILL_LIGHT_COLOR)


#an even width a little narrower than the sprite's canvas, so small and big enemies get fitting bars
func _width_from_sprite() -> int:
	var frames : SpriteFrames = enemy.animation_control.sprite_frames if enemy.animation_control != null else null
	if frames == null or frames.get_animation_names().is_empty():
		return MIN_WIDTH
	var animation : StringName = enemy.animation_control.animation
	if not frames.has_animation(animation):
		animation = frames.get_animation_names()[0]
	var texture : Texture2D = frames.get_frame_texture(animation, 0) if frames.get_frame_count(animation) > 0 else null
	if texture == null:
		return MIN_WIDTH
	var sprite_width : int = texture.get_width() - SPRITE_MARGIN
	return clampi(sprite_width - sprite_width % 2, MIN_WIDTH, MAX_WIDTH)


func _on_option_changed(key : String, value : Variant) -> void:
	if key == SettingsManager.OPTION_HEALTH_BARS:
		is_enabled = value
		_refresh()
