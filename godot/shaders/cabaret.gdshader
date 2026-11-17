shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 6.0) = 2.5;
uniform float grayscale : hint_range(0.0, 1.0) = 1.0;
uniform float levels : hint_range(4.0, 32.0) = 12.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform float exposure : hint_range(0.5, 2.0) = 1.15;
float luminance(vec3 c) { return dot(c,vec3(0.299,0.587,0.114)); }
void fragment() {
 vec2 step_uv=SCREEN_PIXEL_SIZE*pixel_size;
 vec2 uv=(floor(SCREEN_UV/step_uv)+0.5)*step_uv;
 vec3 c=textureLod(screen_texture,uv,0.0).rgb;
 float l=luminance(c)*exposure;
 float edge=abs(luminance(textureLod(screen_texture,uv+vec2(step_uv.x,0.0),0.0).rgb)-luminance(c));
 edge+=abs(luminance(textureLod(screen_texture,uv+vec2(0.0,step_uv.y),0.0).rgb)-luminance(c));
 vec2 cell=floor(SCREEN_UV/step_uv);
 float dither=(mod(cell.x+cell.y*2.0,4.0)/4.0-0.375)/levels;
 l=clamp(l-edge*0.32,0.0,1.0);
 l=floor(clamp(l+dither,0.0,1.0)*(levels-1.0)+0.5)/(levels-1.0);
 vec2 p=(SCREEN_UV-0.5)*vec2(1.0,0.82);
 float shade=1.0-vignette*smoothstep(0.2,0.65,length(p));
 COLOR=vec4(mix(c*exposure,vec3(l),grayscale)*shade,1.0);
}
