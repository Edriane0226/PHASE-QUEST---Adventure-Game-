shader_type canvas_item;
render_mode unshaded;
void fragment() {
	// Keep the original generated artwork; suppress low-alpha export haze.
	COLOR.a *= smoothstep(0.90, 0.97, texture(TEXTURE, UV).a);
}
