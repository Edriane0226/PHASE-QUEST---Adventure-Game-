shader_type canvas_item;

uniform vec2 direction = vec2(1.0, 1.0);
uniform float speed : hint_range(0.0, 10.0) = 0.05;

void fragment() {
    // Loops the UV coordinates mathematically between 0.0 and 1.0
    vec2 scrolled_uv = mod(UV + (direction * TIME * speed), 1.0);
    
    // Standard Godot texture sampling
    COLOR = texture(TEXTURE, scrolled_uv);
}
