shader_type canvas_item;
render_mode unshaded;
uniform float breath : hint_range(0.0,1.0) = 0.0;
uniform bool device_pose = false;
uniform sampler2D upper_body : filter_linear, repeat_disable;
uniform vec2 pose_offset = vec2(0.0);
uniform vec2 torso_band = vec2(98.0,132.0);
uniform vec2 frame_size = vec2(192.0);
uniform vec2 frame_offset = vec2(0.0);
// inner/outer forearm coordinates in signed x, extension, outward sign.
uniform vec4 arm_warp = vec4(0.0);
varying vec2 frame_pixel;
varying vec4 vertex_tint;
void vertex() {
	frame_pixel = VERTEX + frame_size*0.5 - frame_offset;
	vertex_tint = COLOR;
	VERTEX.y = 64.0 + (VERTEX.y-64.0)*(1.0+breath*0.012);
}
void fragment() {
	vec4 art = texture(TEXTURE,UV);
	if (device_pose) {
		if (frame_pixel.y < torso_band.x) {
			// Original head/scarf renders once, above the device, in HeadOccluder.
			art = vec4(0.0);
		} else if (frame_pixel.y < torso_band.y) {
			vec2 source_pixel = frame_pixel-pose_offset;
			if (arm_warp.z > 0.0) {
				float outward = source_pixel.x*arm_warp.w;
				if (outward > arm_warp.x) {
					float span = arm_warp.y-arm_warp.x;
					outward = outward < arm_warp.y+arm_warp.z
						? arm_warp.x+(outward-arm_warp.x)*span/(span+arm_warp.z)
						: outward-arm_warp.z;
					source_pixel.x = outward*arm_warp.w;
				}
			}
			art = texture(upper_body,source_pixel/vec2(192.0));
		}
	}
	COLOR = art*vertex_tint;
	COLOR.a *= smoothstep(0.90,0.97,art.a);
}
