shader_type canvas_item;
void fragment() {
	vec4 scene = texture(TEXTURE, UV);
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0-UV.x);
	edge *= smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.12, 1.0-UV.y);
	COLOR = vec4(scene.rgb, scene.a*edge);
}
