shader_type canvas_item;
render_mode unshaded;
// Shows one of four frames, side by side in the atlas. Vertex red is the starting frame of each cell.
uniform int frame = 0;
varying flat float shift;

void vertex() {
	shift = mod(float(frame) + floor(COLOR.r * 4.0 + 0.5), 4.0) * 0.25;
	COLOR = vec4(1.0);
}

void fragment() {
	COLOR = texture(TEXTURE, UV + vec2(shift, 0.0));
}
