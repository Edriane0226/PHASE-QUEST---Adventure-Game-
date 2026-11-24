shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_source : hint_screen_texture, repeat_disable, filter_linear;
uniform float effect_time = 0.0;
uniform float strength_pixels = 0.35;
void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float mask = 1.0-smoothstep(0.15,0.95,length(centered));
	vec2 ripple = vec2(sin(UV.y*19.0-effect_time*7.0),cos(UV.x*13.0+effect_time*5.0));
	vec4 base = texture(screen_source,SCREEN_UV);
	vec4 shifted = texture(screen_source,SCREEN_UV+ripple*SCREEN_PIXEL_SIZE*strength_pixels*mask);
	COLOR = vec4(mix(base.rgb,shifted.rgb,mask),mask*0.45);
}
