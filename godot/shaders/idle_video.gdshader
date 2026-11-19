shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D video_texture : source_color, filter_linear;
uniform float black_cutoff : hint_range(0.0,0.2) = 0.055;
void fragment() {
 vec4 c=texture(video_texture,UV);
 float key=max(c.r,max(c.g,c.b));
 ALBEDO=c.rgb*1.7;
 ALPHA=smoothstep(black_cutoff,black_cutoff+0.045,key);
 ALPHA_SCISSOR_THRESHOLD=0.12;
}

