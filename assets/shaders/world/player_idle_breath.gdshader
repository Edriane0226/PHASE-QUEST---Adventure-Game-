shader_type canvas_item;
render_mode unshaded;
uniform float breath : hint_range(0.0, 1.0) = 0.0;
void vertex() {
	// Source frames are 192px, with the boot sole approximately 64px below centre.
	VERTEX.y = 64.0 + (VERTEX.y - 64.0) * (1.0 + breath * 0.012);
}
void fragment() {
	COLOR.a *= smoothstep(0.90, 0.97, texture(TEXTURE, UV).a);
}
