shader_type canvas_item;
render_mode unshaded;
// Review only: greyscale and colour-blind simulation with the validator's matrices.
uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform int mode = 0;

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { c = clamp(c, 0.0, 1.0); return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void fragment() {
	vec3 c = to_linear(texture(screen, SCREEN_UV).rgb);
	if (mode == 1) c = vec3(dot(c, vec3(0.2126, 0.7152, 0.0722)));
	if (mode == 2) c = vec3(dot(c, vec3(0.152286, 1.052583, -0.204868)), dot(c, vec3(0.114503, 0.786281, 0.099216)), dot(c, vec3(-0.003882, -0.048116, 1.051998)));
	if (mode == 3) c = vec3(dot(c, vec3(0.367322, 0.860646, -0.227968)), dot(c, vec3(0.280085, 0.672501, 0.047413)), dot(c, vec3(-0.011820, 0.042940, 0.968881)));
	if (mode == 4) c = vec3(dot(c, vec3(1.255528, -0.076749, -0.178779)), dot(c, vec3(-0.078411, 0.930809, 0.147602)), dot(c, vec3(0.004733, 0.691367, 0.303900)));
	COLOR = vec4(to_srgb(c), 1.0);
}
