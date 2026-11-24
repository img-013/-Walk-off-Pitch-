shader_type canvas_item;
void fragment(){vec4 c=texture(TEXTURE,UV);c.a*=1.0-smoothstep(0.48,0.62,UV.x);COLOR=c;}
