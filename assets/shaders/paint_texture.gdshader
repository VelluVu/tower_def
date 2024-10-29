shader_type canvas_item;

uniform sampler2D added_texture;

vec4 get_color_from_uv_pos(vec2 position)
{
	return texture(added_texture, position);
}


void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 added_texture_pixel_color = get_color_from_uv_pos(UV);
	COLOR.rgb = added_texture_pixel_color.rgb;
}


