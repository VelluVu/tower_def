shader_type canvas_item;
render_mode blend_mix;

// Everything outside the playfield is out of play: right at the edge whatever is drawn there (spawns, rock,
// waterfalls) turns grey and dim in a few steps, then an ordered dither of whole world pixels thickens into the
// dark over fog_depth and drifts slowly, so art cut off at the map's edge fades away. Nothing inside the playfield.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.122, 0.078, 0.098, 1.0);
// the playfield in world pixels: x, y, width, height
uniform vec4 playfield = vec4(0.0, 0.0, 768.0, 256.0);
uniform float fog_start : hint_range(0.0, 32.0) = 2.0;
uniform float fog_depth : hint_range(8.0, 160.0) = 64.0;
// how far past the edge the colours are fully greyed, and how dark that grey gets
uniform float grey_depth : hint_range(1.0, 32.0) = 8.0;
uniform float grey_dim : hint_range(0.0, 1.0) = 0.45;
uniform float drift_amount : hint_range(0.0, 1.0) = 0.35;
uniform float drift_scale : hint_range(4.0, 96.0) = 28.0;
uniform float drift_speed : hint_range(0.0, 16.0) = 4.0;

varying vec2 world_pos;


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
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment()
{
	vec2 pixel = floor(world_pos);
	vec2 centre = pixel + 0.5;
	vec2 outside = max(playfield.xy - centre, centre - (playfield.xy + playfield.zw));
	float distance_out = length(max(outside, vec2(0.0)));
	float amount = clamp((distance_out - fog_start) / fog_depth, 0.0, 1.0);

	// two noise layers drifting different ways; only where there is fog, so the playfield stays clear
	float drift = value_noise(centre / drift_scale + vec2(TIME * drift_speed / drift_scale, 0.0))
		+ value_noise(centre / (drift_scale * 0.6) - vec2(0.0, TIME * drift_speed * 0.7 / drift_scale));
	amount = clamp(amount + (drift - 1.0) * drift_amount * step(0.001, amount) * (1.0 - amount), 0.0, 1.0);

	// three grey steps, so the change reads as pixel art and not as a smooth gradient
	float grey = floor(clamp(distance_out / grey_depth, 0.0, 1.0) * 3.0 + 0.999) / 3.0;
	vec3 under = texture(screen_texture, SCREEN_UV).rgb;
	vec3 greyed = mix(vec3(dot(under, vec3(0.299, 0.587, 0.114))), fog_color.rgb, grey_dim * grey);
	vec3 out_of_play = mix(under, greyed, grey);

	float fogged = step(bayer(pixel) + 0.001, amount);
	COLOR = vec4(mix(out_of_play, fog_color.rgb, fogged), step(0.001, distance_out));
}
