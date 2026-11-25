shader_type canvas_item;
render_mode unshaded;
// One pass over the finished picture: ambient plus up to six lights in hard bands, on whole art pixels.
// The same maths runs on desktop and on phones.
uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec3 ambient = vec3(1.0);
uniform vec4 place[6]; // x, y, radius, strength
uniform vec3 tint[6];
varying vec2 world;

void vertex() { world = VERTEX; }

// Three bands (PX-03 approval). The edge wanders, so a pool of light does not look like a target.
float band(float r) {
	if (r < 0.36) return 1.0;
	if (r < 0.68) return 0.58;
	if (r < 1.0) return 0.24;
	return 0.0;
}

void fragment() {
	vec2 p = floor(world) + 0.5;
	vec3 sum = ambient;
	for (int i = 0; i < 6; i++) {
		// The ground is seen at 2:1, so a round pool of light is twice as wide as high.
		// A light replaces the ambient colour band by band, so warm light stays warm on cold snow.
		vec2 d = ((floor(p / vec2(2.0, 1.0)) + 0.5) * vec2(2.0, 1.0) - place[i].xy) * vec2(1.0, 2.0);
		float turn = atan(d.y, d.x);
		float wander = sin(turn * 5.0 + float(i)) * 0.035 + sin(turn * 9.0 + float(i) * 2.0) * 0.025 + sin(turn * 17.0) * 0.012;
		float r = length(d) / max(place[i].z, 1.0) + wander;
		sum = mix(sum, max(sum, tint[i]) * vec3(1.0, 1.0, 0.0) + vec3(0.0, 0.0, tint[i].b), band(r) * place[i].w);
	}
	COLOR = vec4(texture(screen, SCREEN_UV).rgb * sum, 1.0);
}
