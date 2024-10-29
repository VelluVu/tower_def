shader_type canvas_item;


uniform float speed = 2.0;


void fragment(){
    COLOR = texture(TEXTURE, vec2(UV.x - TIME * speed, UV.y));
}