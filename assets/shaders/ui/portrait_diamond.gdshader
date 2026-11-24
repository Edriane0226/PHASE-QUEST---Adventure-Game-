shader_type canvas_item;
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float diamond = abs(UV.x - 0.5) + abs(UV.y - 0.5);
	color.a *= 1.0 - smoothstep(0.47, 0.49, diamond);
	COLOR *= color;
}
