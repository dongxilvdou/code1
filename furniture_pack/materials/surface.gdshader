shader_type spatial;
uniform vec4 tint : source_color = vec4(0.6, 0.4, 0.25, 1.0);
uniform float finish = 0.75;
uniform int pattern = 0;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	float detail = 1.0;
	if (pattern == 1) {
		float phase = local_pos.x * 170.0 + sin(local_pos.z * 5.0) * 3.0 + sin(local_pos.x * 28.0 + local_pos.z * 2.0);
		float fine_phase = local_pos.x * 530.0 + local_pos.z * 10.0;
		float grain = sin(phase) * clamp(1.0-fwidth(phase), 0.0, 1.0);
		detail = 0.96 + 0.04 * grain + 0.018 * sin(fine_phase) * clamp(1.0-fwidth(fine_phase), 0.0, 1.0);
	} else if (pattern == 2) {
		// Filter fine woven threads to avoid crawling at a cat's low view angle.
		vec2 p = vec2(local_pos.x + local_pos.z, local_pos.y + local_pos.z) * 650.0;
		vec2 fade = clamp(vec2(1.0) - fwidth(p), vec2(0.0), vec2(1.0));
		detail = 0.97 + 0.018 * sin(p.x) * fade.x + 0.018 * sin(p.y) * fade.y;
	} else if (pattern == 3) {
		detail = 0.97 + 0.025 * sin(local_pos.x * 11.0 + sin(local_pos.z * 8.0) + local_pos.y * 6.0);
	}
	ALBEDO = tint.rgb * detail;
	ROUGHNESS = finish;
}
