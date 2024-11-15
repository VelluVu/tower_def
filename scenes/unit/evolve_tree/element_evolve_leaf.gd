class_name ElementEvolveLeaf
extends EvolveLeaf


@export var selected_icon : Texture2D = null
@export var new_skill_scene : PackedScene = null
@export var new_projectile_scene : PackedScene = null
@export var new_beam_texture : CompressedTexture2D = null
@export var new_animated_sprite_scene : PackedScene = null
@export var new_damage_data_scene : PackedScene = null


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
