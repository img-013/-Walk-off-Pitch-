shader_type canvas_item;
render_mode unshaded;
uniform bool fade_right = false;
uniform bool effect_enabled = true;
uniform float pixel_size : hint_range(1.0, 6.0) = 2.5;
uniform float grayscale : hint_range(0.0, 1.0) = 1.0;
uniform float levels : hint_range(4.0, 32.0) = 12.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform float exposure : hint_range(0.5, 2.0) = 1.15;
float luminance(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
 vec2 step_uv=max(fwidth(UV)*pixel_size,vec2(0.000001));
 vec2 uv=(floor(UV/step_uv)+0.5)*step_uv;
 vec4 original=texture(TEXTURE,UV);
 vec3 c=texture(TEXTURE,uv).rgb;
 float l=luminance(c)*exposure;
 float edge=abs(luminance(texture(TEXTURE,uv+vec2(step_uv.x,0.0)).rgb)-luminance(c));
 edge+=abs(luminance(texture(TEXTURE,uv+vec2(0.0,step_uv.y)).rgb)-luminance(c));
 vec2 cell=floor(UV/step_uv);
 float dither=(mod(cell.x+cell.y*2.0,4.0)/4.0-0.375)/levels;
 l=clamp(l-edge*0.32,0.0,1.0);
 l=floor(clamp(l+dither,0.0,1.0)*(levels-1.0)+0.5)/(levels-1.0);
 vec2 p=(SCREEN_UV-0.5)*vec2(1.0,0.82);
 float shade=1.0-vignette*smoothstep(0.2,0.65,length(p));
 vec3 result=effect_enabled ? mix(c*exposure,vec3(l),grayscale)*shade : original.rgb;
 float alpha=original.a*(fade_right ? 1.0-smoothstep(0.48,0.62,UV.x) : 1.0);
 COLOR=vec4(result,alpha);
}
