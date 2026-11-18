class_name Elite
extends Node

## Makes its enemy an elite (Elite.make): tougher, worth more gold and XP, tinted, with one affix.
## Elites are mixed into normal waves (SpawnGroupData.elites), never a whole wave of them.
## An enemy whose sheet has an elite version next to it (<sheet>_elite.png, same cell layout, drawn by
## tools/sprite/parts/elites.py: golden armour, crowns and other ornaments) wears it, and its tint is lighter.

enum Affix
{
	Random,
	## Takes 40% less damage.
	Shielded,
	## 40% faster.
	Hasted,
	## Heals 3% of its max health every second.
	Regenerating,
	## Splits into two smaller copies when it dies.
	Splitting,
	## 60% faster once it is below half health.
	Enraged,
}

const NAME : String = "Elite"
const HEALTH_MULTIPLIER : float = 2.5
const GOLD_MULTIPLIER : float = 3.0
const XP_MULTIPLIER : float = 2.5
const SHIELD_DAMAGE_FACTOR : float = 0.6
const HASTE : float = 0.4
const REGENERATION_PER_SECOND : float = 0.03
const SPLIT_COUNT : int = 2
const SPLIT_HEALTH : float = 0.4
const ENRAGE_HEALTH_RATIO : float = 0.5
const ENRAGE_HASTE : float = 0.6
#multiplied into the sprite's colour, one hue per affix
const TINTS : Dictionary[Affix, Color] = {
	Affix.Shielded: Color(0.7, 0.82, 1.0),
	Affix.Hasted: Color(1.0, 0.92, 0.55),
	Affix.Regenerating: Color(0.65, 1.0, 0.65),
	Affix.Splitting: Color(0.92, 0.68, 1.0),
	Affix.Enraged: Color(1.0, 0.58, 0.52),
}
const DISPLAY_TEXT : String = "%s %s"
const ELITE_SHEET_FORMAT : String = "%s_elite.%s"
#with elite art the affix tint only hints, so the gold stays gold
const ART_TINT_STRENGTH : float = 0.35

#an enemy scene's SpriteFrames -> its elite copy (null: no elite sheet), shared by every elite of that scene
static var elite_frames_cache : Dictionary[SpriteFrames, SpriteFrames] = {}

var enemy : Enemy = null
var affix : Affix = Affix.Shielded
var is_enraged : bool = false
var regeneration_timer : CustomTimer = null


## Turns a spawned enemy (already in the tree, its wave health applied) into an elite.
static func make(target : Enemy, chosen : Affix) -> Elite:
	var elite : Elite = Elite.new()
	elite.name = NAME
	elite.affix = chosen if chosen != Affix.Random else (randi_range(1, Affix.size() - 1) as Affix)
	elite.enemy = target
	target.add_child(elite)
	return elite


static func multiply(stat_type : Utils.StatType, multiplier : float) -> ModifierData:
	var modifier : ModifierData = ModifierData.new()
	modifier.modifier_type = Utils.ModifierType.StatModifier
	modifier.calculate_type = Utils.ModifyType.Multiply
	modifier.stat_type = stat_type
	modifier.value = multiplier - 1.0
	return modifier


## Which members of a group of `count` are elites, spread evenly: the ith (from 0) one is when this is true.
static func is_elite_index(index : int, count : int, elites : int) -> bool:
	if elites <= 0 or count <= 0:
		return false
	return floori((index + 1) * mini(elites, count) / float(count)) > floori(index * mini(elites, count) / float(count))


func _ready() -> void:
	enemy.modifier_manager.add_modifier(multiply(Utils.StatType.MaxHealth, HEALTH_MULTIPLIER))
	enemy.stats.get_stat(Utils.StatType.Health).value = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
	enemy.modifier_manager.add_modifier(multiply(Utils.StatType.Price, GOLD_MULTIPLIER))
	enemy.xp_multiplier *= XP_MULTIPLIER
	var has_art : bool = _wear_elite_art()
	enemy.animation_control.modulate = Color.WHITE.lerp(TINTS[affix], ART_TINT_STRENGTH) if has_art else TINTS[affix]
	var selectable : SelectableUnit = _find_selectable()
	if selectable != null:
		selectable.display_name = DISPLAY_TEXT % [Affix.keys()[affix], selectable._get_display_name()]

	match affix:
		Affix.Shielded:
			enemy.damage_taken_factor *= SHIELD_DAMAGE_FACTOR
		Affix.Hasted:
			enemy.modifier_manager.add_modifier(multiply(Utils.StatType.Speed, 1.0 + HASTE))
		Affix.Regenerating:
			regeneration_timer = CustomTimer.new()
			add_child(regeneration_timer)
			regeneration_timer.unscaled_base_value = 1.0
			regeneration_timer.timeout.connect(_regenerate)
			regeneration_timer.start()
		Affix.Splitting:
			GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
		Affix.Enraged:
			GameSignals.enemy_hit.connect(_on_enemy_hit)


## The frames with every sheet region moved to the elite sheet, or null when the sheet has no elite version.
static func get_elite_frames(frames : SpriteFrames) -> SpriteFrames:
	if frames == null:
		return null
	if elite_frames_cache.has(frames):
		return elite_frames_cache[frames]

	var elite_frames : SpriteFrames = SpriteFrames.new()
	var has_elite_sheet : bool = false
	for animation in frames.get_animation_names():
		if not elite_frames.has_animation(animation):
			elite_frames.add_animation(animation)
		elite_frames.set_animation_speed(animation, frames.get_animation_speed(animation))
		elite_frames.set_animation_loop(animation, frames.get_animation_loop(animation))
		for i in frames.get_frame_count(animation):
			var texture : Texture2D = frames.get_frame_texture(animation, i)
			var elite_texture : Texture2D = _get_elite_texture(texture)
			has_elite_sheet = has_elite_sheet or elite_texture != texture
			elite_frames.add_frame(animation, elite_texture, frames.get_frame_duration(animation, i))
	#SpriteFrames.new() starts with a "default" animation
	if not frames.has_animation(&"default") and elite_frames.has_animation(&"default"):
		elite_frames.remove_animation(&"default")

	elite_frames_cache[frames] = elite_frames if has_elite_sheet else null
	return elite_frames_cache[frames]


#the same region of <sheet>_elite.png, or the texture itself when there is none
static func _get_elite_texture(texture : Texture2D) -> Texture2D:
	var atlas_texture : AtlasTexture = texture as AtlasTexture
	if atlas_texture == null or atlas_texture.atlas == null or atlas_texture.atlas.resource_path.is_empty():
		return texture

	var path : String = atlas_texture.atlas.resource_path
	var elite_path : String = ELITE_SHEET_FORMAT % [path.get_basename(), path.get_extension()]
	if not ResourceLoader.exists(elite_path):
		return texture

	var elite_texture : AtlasTexture = atlas_texture.duplicate()
	elite_texture.atlas = load(elite_path)
	return elite_texture


#swaps the sprite to the elite sheet, keeping the animation and frame it is on
func _wear_elite_art() -> bool:
	var sprite : AnimationControl = enemy.animation_control
	var elite_frames : SpriteFrames = get_elite_frames(sprite.sprite_frames)
	if elite_frames == null:
		return false

	var animation : StringName = sprite.animation
	var frame : int = sprite.frame
	var was_playing : bool = sprite.is_playing()
	sprite.sprite_frames = elite_frames
	sprite.animation = animation
	sprite.frame = frame
	if was_playing:
		sprite.play(animation)
	return true


func _find_selectable() -> SelectableUnit:
	for child in enemy.get_children():
		if child is SelectableUnit:
			return child
	return null


func _regenerate() -> void:
	if enemy.is_dead or enemy.is_deactivated:
		return
	var health : Stat = enemy.stats.get_stat(Utils.StatType.Health)
	var max_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
	health.value = minf(health.value + max_health * REGENERATION_PER_SECOND, max_health)


#killed, not leaked: two smaller copies come out where it fell
func _on_enemy_destroyed(destroyed : Enemy) -> void:
	if destroyed != enemy or not enemy.gives_reward or not enemy.is_dead or enemy.scene_file_path.is_empty():
		return

	var copies : Array[Enemy] = EnemySummon.summon_around(load(enemy.scene_file_path), enemy, SPLIT_COUNT, enemy.grid_position)
	for copy in copies:
		LevelModeData.scale_health(copy, SPLIT_HEALTH)


func _on_enemy_hit(hit_enemy : Enemy, _damage_data : DamageData) -> void:
	if hit_enemy != enemy or is_enraged or enemy.is_dead:
		return

	var max_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
	if max_health > 0.0 and enemy.stats.get_stat_value(Utils.StatType.Health) / max_health < ENRAGE_HEALTH_RATIO:
		is_enraged = true
		enemy.modifier_manager.add_modifier(multiply(Utils.StatType.Speed, 1.0 + ENRAGE_HASTE))
