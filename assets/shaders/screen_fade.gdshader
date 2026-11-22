shader_type canvas_item;

// Covers the screen with an ordered (4x4 Bayer) dither: progress 1 covers everything, 0 nothing.
// The stretch mode is "viewport" (the game renders at 640x360, then scales), so FRAGCOORD counts
// UI pixels and the cells stay whole: the fade dissolves in chunky pixel steps, not a smooth alpha.

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fade_color : source_color = vec4(0.039, 0.090, 0.071, 1.0);
// UI pixels per dither cell
uniform float cell_size = 2.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	ivec2 cell = ivec2(floor(FRAGCOORD.xy / cell_size));
	int index = (cell.x % 4) + (cell.y % 4) * 4;
	float threshold = (BAYER[index] + 0.5) / 16.0;
	COLOR = fade_color;
	COLOR.a = progress > threshold ? 1.0 : 0.0;
}
