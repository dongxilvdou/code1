shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha, shadows_disabled;
uniform sampler2D video_frame : source_color, filter_linear;
uniform float key_low = 0.06;
uniform float key_high = 0.28;
void fragment() {
	vec3 rgb = texture(video_frame, UV).rgb;
	float green_excess = rgb.g - max(rgb.r, rgb.b);
	float matte = 1.0 - smoothstep(key_low, key_high, green_excess);
	if (matte < 0.015) discard;
	// Suppress green spill on the soft, compressed source edges.
	rgb.g = min(rgb.g, max(rgb.r, rgb.b) + 0.035);
	ALBEDO = rgb;
	ALPHA = matte;
}
