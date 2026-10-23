shader_type canvas_item;

// Every unit sprite: the hit flash (AnimationControl.play_hit_animation steps `flash` 1 -> 0.5 -> 0)
// and the selection outline (SelectableUnit toggles `outline_enabled`). One material per unit
// (resource_local_to_scene), so selecting no longer swaps the material and hides the flash.

uniform vec4 hit_color : source_color = vec4(0.83, 0.13, 0.0, 1.0);
uniform vec4 outline_color : source_color = vec4(0.0, 0.745, 0.875, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width : hint_range(0.0, 10.0) = 0.5;
uniform int outline_pattern : hint_range(0, 2) = 2; // diamond, circle, square
uniform bool outline_enabled = false;

// vertex colour with the node's modulate (the corpse fade), applied after the texture is sampled
varying vec4 vertex_color;

// The outline grows the quad by its width; without it the sprite samples exactly as a plain sprite.
float get_margin() {
	return outline_enabled ? outline_width : 0.0;
}

void vertex() {
	vertex_color = COLOR;
	VERTEX += (UV * 2.0 - 1.0) * get_margin();
}

bool has_opaque_neighbour(vec2 uv, vec2 texture_pixel_size, sampler2D tex) {
	for (float i = -ceil(outline_width); i <= ceil(outline_width); i++) {
		float x = abs(i) > outline_width ? outline_width * sign(i) : i;
		float offset;

		if (outline_pattern == 0) {
			offset = outline_width - abs(x);
		} else if (outline_pattern == 1) {
			offset = floor(sqrt(pow(outline_width + 0.5, 2) - x * x));
		} else {
			offset = outline_width;
		}

		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			float y = abs(j) > offset ? offset * sign(j) : j;
			vec2 xy = uv + texture_pixel_size * vec2(x, y);

			if (xy == clamp(xy, vec2(0.0), vec2(1.0)) && texture(tex, xy).a > 0.0) {
				return true;
			}
		}
	}

	return false;
}

void fragment() {
	float margin = get_margin();
	vec2 grown_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(margin * 2.0));
	vec2 uv = (UV - grown_pixel_size * margin) * TEXTURE_PIXEL_SIZE / grown_pixel_size;

	vec4 color = uv == clamp(uv, vec2(0.0), vec2(1.0)) ? texture(TEXTURE, uv) : vec4(0.0);
	color.rgb = mix(color.rgb, hit_color.rgb, flash);

	if (outline_enabled && color.a <= 0.0 && has_opaque_neighbour(uv, TEXTURE_PIXEL_SIZE, TEXTURE)) {
		color.rgb = outline_color.rgb;
		color.a += (1.0 - color.a) * outline_color.a;
	}

	COLOR = color * vertex_color;
}
