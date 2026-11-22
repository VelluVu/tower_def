class_name HitEffects
extends Node2D

## What a tower's hit looks like on an enemy (polish, 2026-11-22, the user: "different effects with
## different tower spells, when hitting enemy"). Made by Level. Art from tools/art/hit_effects.py.
## By the tower's skill: a projectile (Bolter) bursts in its element, a trap (melee) leaves claw
## marks, a beam tick or a Nova burst (and splash) sparks small, at most every BURST_GAP_MSEC on one
## enemy so a beam or a crowd never floods the screen. A crit adds a star. Overtime ticks, heals and
## reactions show nothing here. Options -> Display -> Hit effects. Cosmetic: real time.

const HITS_FOLDER : String = "res://assets/art/effects/hits/%s_%s.png"
const CRIT_STAR : Texture2D = preload("res://assets/art/effects/hits/crit_star.png")
const BURST : String = "burst"
const SPARK : String = "spark"
const CLAW : String = "claw"
const CAST : String = "cast"
const DEATH : String = "death"
## A skill's own damage data child: its element (Skill.damage_data would make a copy to free).
const DAMAGE_DATA_NODE : NodePath = ^"DamageData"
## The skills whose firing flashes: a beam shows itself, a trap's claws are on the hit.
const CAST_SKILLS : Array[Utils.SkillType] = [Utils.SkillType.Projectile, Utils.SkillType.Area]
const ELEMENT_NAMES : Dictionary[Utils.DamageType, String] = {
	Utils.DamageType.Physical: "physical",
	Utils.DamageType.Fire: "fire",
	Utils.DamageType.Frost: "frost",
	Utils.DamageType.Poison: "poison",
}
const BIG_FRAME : int = 16
const SMALL_FRAME : int = 8
const FRAME_SECONDS : float = 0.05
## Over the units and the dust puffs, under the damage numbers' layer.
const HIT_Z_INDEX : int = 21
## Hits land a little apart, so a run of them does not stack on one pixel.
const JITTER : int = 2
## Beam ticks and Nova bursts on one enemy: at most one spark this often.
const SPARK_GAP_MSEC : int = 150
## Past this many effects on screen only the projectile bursts, claws and crits still show.
const MAX_LIVE : int = 48

var _sheets : Dictionary[String, Texture2D] = {}
#enemy instance id -> Time.get_ticks_msec() of its last spark
var _last_spark : Dictionary[int, int] = {}
#enemy instance id -> the damage type that hit it last (ticks too): how it dies
var _last_element : Dictionary[int, Utils.DamageType] = {}


func _ready() -> void:
	z_index = HIT_Z_INDEX
	GameSignals.enemy_hit.connect(_on_enemy_hit)
	GameSignals.tower_attacked.connect(_on_tower_attacked)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func _on_enemy_hit(enemy : Enemy, damage_data : DamageData) -> void:
	if not SettingsManager.get_option(SettingsManager.OPTION_HIT_EFFECTS):
		return
	#a burn or poison tick that kills counts as its element too
	if is_instance_valid(enemy) and damage_data.damage > 0.0 and ELEMENT_NAMES.has(damage_data.damage_type) and not damage_data.is_healing:
		_last_element[enemy.get_instance_id()] = damage_data.damage_type
	var style : String = get_style(damage_data)
	if style.is_empty() or not is_instance_valid(enemy):
		return
	if style == SPARK:
		var now : int = Time.get_ticks_msec()
		var id : int = enemy.get_instance_id()
		if now - _last_spark.get(id, -SPARK_GAP_MSEC) < SPARK_GAP_MSEC or get_child_count() >= MAX_LIVE:
			return
		_last_spark[id] = now
	var at : Vector2 = _hit_point(enemy)
	play(get_sheet(style, damage_data.damage_type), SMALL_FRAME if style == SPARK else BIG_FRAME, at)
	if damage_data.is_critical:
		play(CRIT_STAR, BIG_FRAME, at)


## The Bolter's and the Nova's mouth flash in their element as they fire.
func _on_tower_attacked(skill : Skill) -> void:
	if not SettingsManager.get_option(SettingsManager.OPTION_HIT_EFFECTS) or not is_instance_valid(skill):
		return
	if not CAST_SKILLS.has(skill.skill_type) or not skill.actor is Building or get_child_count() >= MAX_LIVE:
		return
	var data : DamageData = skill.get_node_or_null(DAMAGE_DATA_NODE) as DamageData
	if data == null or not ELEMENT_NAMES.has(data.damage_type):
		return
	play(get_sheet(CAST, data.damage_type), SMALL_FRAME, skill.global_position)


## Fire burns it up, Frost shatters it, Poison melts it into gas; a physical death keeps its gore only.
func _on_enemy_destroyed(enemy : Enemy) -> void:
	var id : int = enemy.get_instance_id()
	var element : Utils.DamageType = _last_element.get(id, Utils.DamageType.None)
	_last_element.erase(id)
	_last_spark.erase(id)
	if element == Utils.DamageType.None or element == Utils.DamageType.Physical:
		return
	if not SettingsManager.get_option(SettingsManager.OPTION_HIT_EFFECTS):
		return
	play(get_sheet(DEATH, element), BIG_FRAME, _hit_point(enemy))


## Which effect a hit gets: "" for none (no tower behind it, a tick, a heal, a reaction, no damage).
static func get_style(damage_data : DamageData) -> String:
	if damage_data.damage <= 0.0 or damage_data.is_overtime or damage_data.is_healing or damage_data.is_reaction or damage_data.is_shielding:
		return ""
	if not damage_data.source is Building or not ELEMENT_NAMES.has(damage_data.damage_type):
		return ""
	if damage_data.is_splash:
		return SPARK
	var skill : Skill = (damage_data.source as Building).skill
	var skill_type : Utils.SkillType = skill.skill_type if skill != null else Utils.SkillType.None
	match skill_type:
		Utils.SkillType.Projectile:
			return BURST
		Utils.SkillType.Melee:
			return CLAW
		Utils.SkillType.Area, Utils.SkillType.Beaming:
			return SPARK
	return BURST


func get_sheet(style : String, damage_type : Utils.DamageType) -> Texture2D:
	var path : String = HITS_FOLDER % [ELEMENT_NAMES[damage_type], style]
	if not _sheets.has(path):
		_sheets[path] = load(path)
	return _sheets[path]


## One effect at a world position: its frames in turn, then it frees itself.
func play(sheet : Texture2D, frame_size : int, at : Vector2) -> void:
	var sprite : Sprite2D = Sprite2D.new()
	sprite.texture = sheet
	sprite.hframes = int(sheet.get_width() / frame_size)
	add_child(sprite)
	sprite.global_position = at.round()
	var tween : Tween = sprite.create_tween()
	for frame in range(1, sprite.hframes):
		tween.tween_interval(FRAME_SECONDS)
		tween.tween_callback(sprite.set.bind(&"frame", frame))
	tween.tween_interval(FRAME_SECONDS)
	tween.tween_callback(sprite.queue_free)


#the middle of the enemy's sprite, a pixel or two off at random
func _hit_point(enemy : Enemy) -> Vector2:
	var center : Vector2 = enemy.animation_control.global_position if enemy.animation_control != null else enemy.global_position
	return center + Vector2(randi_range(-JITTER, JITTER), randi_range(-JITTER, JITTER))
