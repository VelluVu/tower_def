shader_type canvas_item;

// The world map's fog over the land not reached yet (MapFog, 2026-11-24). How thick it is comes from a small density
// texture MapFog paints (red: 0 clear round the revealed levels and along their trails, 1 deep fog; green: how much
// lava glows under it, which warms the fog's colour), plus the clearings of
// the level being revealed right now, which grow with reveal_progress. The fog is drawn on whole art pixels with a
// 4x4 Bayer dither, so its edge breaks up as pixel art; two value-noise layers drift through its edge and blot its
// body with a darker shade, like a sea of cloud. Drawn on a rect over the whole map, in the map's own units.

uniform sampler2D density_texture : filter_linear;
uniform vec4 fog_light : source_color = vec4(0.753, 0.796, 0.863, 1.0);
uniform vec4 fog_shade : source_color = vec4(0.545, 0.608, 0.706, 1.0);
uniform vec4 glow_light : source_color = vec4(0.965, 0.459, 0.478, 1.0);
uniform vec4 glow_shade : source_color = vec4(0.635, 0.149, 0.2, 1.0);
// the map's size in its units, and how many units one art pixel takes
uniform vec2 map_size = vec2(1200.0, 672.0);
uniform float art_pixel = 2.0;
// the clearings that open while a level is revealed: x, y, radius, the progress at which it starts opening
uniform vec4 reveal_spots[32];
uniform int reveal_count = 0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;
uniform float reveal_edge = 48.0;
uniform float drift_amount : hint_range(0.0, 1.0) = 0.4;
uniform float drift_scale : hint_range(8.0, 160.0) = 56.0;
uniform float drift_speed : hint_range(0.0, 16.0) = 3.0;

varying vec2 local_pos;


float hash(vec2 p)
{
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


// 4x4 Bayer threshold, 0..15/16
float bayer(vec2 pixel)
{
	ivec2 p = ivec2(mod(pixel, 4.0));
	int index = p.x + p.y * 4;
	const float matrix[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return matrix[index] / 16.0;
}


void vertex()
{
	local_pos = VERTEX;
}


void fragment()
{
	vec2 pixel = floor(local_pos / art_pixel);
	vec2 centre = (pixel + 0.5) * art_pixel;
	vec2 fields = texture(density_texture, centre / map_size).rg;
	float density = fields.r;
	for (int i = 0; i < 32; i++)
	{
		if (i >= reveal_count)
		{
			break;
		}
		float opened = smoothstep(reveal_spots[i].w, min(1.0, reveal_spots[i].w + 0.35), reveal_progress);
		float radius = reveal_spots[i].z * opened;
		density = min(density, clamp((distance(centre, reveal_spots[i].xy) - radius) / reveal_edge, 0.0, 1.0) + (1.0 - opened));
	}

	// the drift only stirs the edge, so the clear land stays clear and the deep fog stays whole
	float drift = value_noise(centre / drift_scale + vec2(TIME * drift_speed / drift_scale, 0.0))
		+ value_noise(centre / (drift_scale * 0.6) - vec2(0.0, TIME * drift_speed * 0.7 / drift_scale));
	float edge = density * (1.0 - density) * 4.0;
	float amount = clamp(density + (drift - 1.0) * drift_amount * edge, 0.0, 1.0);
	float fogged = step(bayer(pixel) + 0.001, amount);

	// soft darker patches drifting through the fog, two octaves so they have no cell edges
	vec2 blot_at = centre / (drift_scale * 1.6) + vec2(TIME * drift_speed * 0.5 / drift_scale, 3.7);
	float blot = value_noise(blot_at) * 0.65 + value_noise(blot_at * 2.3 + 11.0) * 0.35;
	float shaded = step(bayer(pixel + 2.0) + 0.001, (blot - 0.42) * 1.8);
	// over lava the fog takes the glow's colours, dithered in by how much lava is under it
	float glowing = step(bayer(pixel + 1.0) + 0.001, fields.g);
	vec3 light = mix(fog_light.rgb, glow_light.rgb, glowing);
	vec3 shade = mix(fog_shade.rgb, glow_shade.rgb, glowing);
	COLOR = vec4(mix(light, shade, shaded), fogged);
}
