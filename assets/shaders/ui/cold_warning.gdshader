shader_type canvas_item;
uniform float strength = 0.0;
uniform float beat = 0.0;
void fragment() {
	vec2 edge = abs(UV - vec2(0.5)) * 2.0;
	float vignette = smoothstep(0.35, 1.0, max(edge.x, edge.y));
	COLOR = vec4(0.8, 0.025, 0.045, vignette * strength * (0.16 + beat * 0.3));
}
