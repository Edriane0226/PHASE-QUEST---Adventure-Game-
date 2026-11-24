shader_type canvas_item;
uniform sampler2D fog_texture : filter_linear, repeat_disable;
uniform bool has_fog = false;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
}
void fragment() {
    vec4 color = texture(TEXTURE, UV);
    if (has_fog) {
        float discovered = texture(fog_texture, UV).r;
        color.rgb = mix(vec3(0.13, 0.21, 0.17), color.rgb, discovered);
    }
    color.a *= 1.0 - smoothstep(0.485, 0.495, length(UV - vec2(0.5)));
    COLOR = color * vertex_tint;
}
