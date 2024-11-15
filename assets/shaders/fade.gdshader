shader_type canvas_item;
render_mode blend_mix;

#define MAX_FADE 4

uniform int fade : hint_range( 0, MAX_FADE, 1 ) = 0;
uniform int tiling = 10;


float get_line( float uv )
{
	uv *= float( tiling );
	uv += float( tiling ) / 2.0;
	return round( mod( uv , 1.0 ) );
}


float get_grid( vec2 uv )
{
	float offset = 0.5 / float( tiling );
	float grids[MAX_FADE];
	for ( int i = 0; i< MAX_FADE/2; i++)
		for ( int j = 0; j< MAX_FADE/2; j++)
		{
			grids[ i * MAX_FADE/2 + j ] = get_line( uv.x + offset*float(i) ) * get_line( uv.y + offset*float(j) );
		}

	float float_fade = float( fade );
	grids[0] *= clamp( 1.0 - float_fade, 0.0, 1.0 );
	grids[1] *= clamp( 3.0 - float_fade, 0.0, 1.0 );
	grids[2] *= clamp( 4.0 - float_fade, 0.0, 1.0 );
	grids[3] *= clamp( 2.0 - float_fade, 0.0, 1.0 );
	
	return grids[0] + grids[1] + grids[2] + grids[3];
}


void fragment()
{
	COLOR.a = COLOR.a * get_grid( UV );
}