shader_type canvas_item;

// A boss lair's light (LairLighting, 2026-11-24): set on the level's tile layers (and the castle's camouflage), it
// darkens their pixels down to `ambient` and lights them back up around each light. The brightness comes in `bands`
// steps with a 4x4 Bayer dither between them on whole world pixels, so a light reads as pixel art rings, not a smooth
// gradient. Units, towers and their bars do not use it and stay at full brightness.

uniform vec4 ambient : source_color = vec4(0.42, 0.42, 0.58, 1.0);
// per light: x, y in world pixels, radius in world pixels, strength
uniform vec4 lights[64];
// per light: rgb, unused
uniform vec4 light_colors[64];
uniform int light_count = 0;
uniform float bands : hint_range(2.0, 16.0) = 6.0;
// how far a light may brighten past the art's own colours, and how much of its colour it adds on top (the floors are
// dark, so a pool of light shows by its tint as much as by its brightness)
uniform float max_light : hint_range(1.0, 3.0) = 1.6;
uniform float glow : hint_range(0.0, 0.5) = 0.14;

varying vec2 world_pos;


float bayer(vec2 pixel)
{
	ivec2 p = ivec2(mod(pixel, 4.0));
	int index = p.x + p.y * 4;
	const float matrix[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return matrix[index] / 16.0;
}


void vertex()
{
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment()
{
	vec4 colour = texture(TEXTURE, UV) * COLOR;
	vec2 pixel = floor(world_pos);
	vec2 centre = pixel + 0.5;
	vec3 lit = vec3(0.0);
	for (int i = 0; i < 64; i++)
	{
		if (i >= light_count)
		{
			break;
		}
		// broad in the middle, fading at the rim
		float reach = distance(centre, lights[i].xy) / max(lights[i].z, 1.0);
		float falloff = clamp(1.0 - reach * reach, 0.0, 1.0);
		lit += light_colors[i].rgb * lights[i].w * falloff;
	}
	float threshold = bayer(pixel);
	vec3 light = clamp(ambient.rgb + lit, vec3(0.0), vec3(max_light));
	vec3 stepped = max(floor(light * bands + threshold) / bands, ambient.rgb * 0.75);
	vec3 tint = floor(clamp(lit, 0.0, 1.0) * bands + threshold) / bands;
	COLOR = vec4(clamp(colour.rgb * stepped + tint * glow, 0.0, 1.0), colour.a);
}
