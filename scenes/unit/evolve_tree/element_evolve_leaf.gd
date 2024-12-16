class_name ElementEvolveLeaf
extends EvolveLeaf


const FIRE_COLOR_HEX : int = 0xff8472
const FROST_COLOR_HEX : int = 0x7effff
const POISON_COLOR_HEX : int = 0x92ff7e

@export var evolve_element : Utils.Element = Utils.Element.Normal
@export var selected_icon : Texture2D = null
@export var new_skill_scene : PackedScene = null
@export var new_projectile_scene : PackedScene = null
@export var new_beam_texture : CompressedTexture2D = null
@export var new_animated_sprite_scene : PackedScene = null
@export var new_damage_data_scene : PackedScene = null
@export var evolve_glow_color : Color = Color.WHITE :
	get:
		match(evolve_element):
			Utils.Element.Normal:
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
		
		#if new skill the damage data of skill will be included to the scene
		if new_skill_scene != null:
			actor.replace_skill(new_skill_scene)
			return
		
		if new_projectile_scene != null:
			actor.skill.new_projectile(new_projectile_scene)
		
		if new_beam_texture != null:
			actor.skill.beam_texture = new_beam_texture
		
		if new_damage_data_scene != null:
			actor.skill.replace_damage_data(new_damage_data_scene)
		
		actor.evolve_glow.modulate = evolve_glow_color
		actor.evolve_tree.evolve_element = evolve_element
		
		for modifier in modifiers:
			actor.modifier_manager.add_modifier(modifier.get_modifier_data())
