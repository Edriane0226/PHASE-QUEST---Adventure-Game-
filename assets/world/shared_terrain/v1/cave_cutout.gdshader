shader_type canvas_item;
render_mode unshaded;
void fragment() {
	// Match existing cutout-art alpha policy; base contact shadow is a separate sprite.
	COLOR.a *= smoothstep(0.90, 0.97, texture(TEXTURE, UV).a);
}
