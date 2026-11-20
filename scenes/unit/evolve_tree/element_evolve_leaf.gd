class_name ElementEvolveLeaf
extends EvolveLeaf


const FIRE_COLOR_HEX : int = 0xff8472
const FROST_COLOR_HEX : int = 0x7effff
const POISON_COLOR_HEX : int = 0x92ff7e

@export var evolve_element : Utils.Element = Utils.Element.Physical
@export var selected_icon : Texture2D = null
@export var new_skill_scene : PackedScene = null
@export var new_projectile_scene : PackedScene = null
@export var new_beam_texture : CompressedTexture2D = null
@export var new_animated_sprite_scene : PackedScene = null
@export var new_damage_data_scene : PackedScene = null
## The tiers after this element, in order (T2, T3), bought one at a time.
@export var tiers : Array[EvolveTierData] = []
@export var evolve_glow_color : Color = Color.WHITE :
	get:
		match(evolve_element):
			Utils.Element.Physical:
				return Color.WHITE
			Utils.Element.Fire:
				return Color.RED
			Utils.Element.Frost:
				return Color.SKY_BLUE
			Utils.Element.Poison:
				return Color.YELLOW_GREEN
			_:
				return Color.WHITE

var modifiers : Array[Modifier] :
	get:
		for child in get_children():
			if child is Modifier:
				if modifiers.has(child):
					continue
				modifiers.append(child)
		return modifiers


#replace old stuff with new evolved stuff
func evolve(actor : Node) -> void:
	super(actor)
	if actor is Building:
		actor.icon = selected_icon
		if new_animated_sprite_scene != null:
			actor.replace_animation_control(new_animated_sprite_scene)
		
		#the rest applies to the swapped skill too: the element, glow and modifiers must not be skipped
		if new_skill_scene != null:
			actor.replace_skill(new_skill_scene)

		if new_projectile_scene != null:
			actor.skill.new_projectile(new_projectile_scene)

		if new_beam_texture != null:
			actor.skill.beam_texture = new_beam_texture

		if new_damage_data_scene != null:
			actor.skill.replace_damage_data(new_damage_data_scene)

		actor.evolve_glow.modulate = evolve_glow_color
		actor.evolve_tree.choose_element(evolve_element)
		
		for modifier in modifiers:
			actor.modifier_manager.add_modifier(modifier.get_modifier_data())


## Tier index 0 is T2. The element itself (T1) was applied by evolve.
func evolve_tier(actor : Building, tier_index : int) -> void:
	if tier_index < 0 or tier_index >= tiers.size():
		return

	var tier : EvolveTierData = tiers[tier_index]
	if actor.evolve_tree != null:
		actor.evolve_tree.tier = maxi(actor.evolve_tree.tier, tier_index + 2)
	for resource in tier.upgrade_resources:
		actor.modifier_manager.add_modifier(resource.get_modifier_data())

	if tier.sprite_frames != null:
		var current_animation : StringName = actor.animation_control.animation
		actor.animation_control.sprite_frames = tier.sprite_frames
		actor.animation_control.play_animation(current_animation)
