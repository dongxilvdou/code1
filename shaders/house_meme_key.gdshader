shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha, shadows_disabled;
uniform sampler2D video_frame : source_color, filter_linear;
void fragment() {
	vec3 rgb = texture(video_frame, UV).rgb;
	float maximum = max(rgb.r, max(rgb.g, rgb.b));
	float minimum = min(rgb.r, min(rgb.g, rgb.b));
	float chroma = maximum - minimum;
	float saturation = chroma / max(maximum, 0.0001);
	float green_hue = 60.0 * ((rgb.b - rgb.r) / max(chroma, 0.0001) + 2.0);
	// Hue gating preserves the banana's yellow peel, unlike a green-channel threshold.
	float key = 0.0;
	if (rgb.g >= rgb.r && rgb.g >= rgb.b) {
		key = smoothstep(88.0, 102.0, green_hue)
			* (1.0 - smoothstep(155.0, 172.0, green_hue))
			* smoothstep(0.20, 0.50, saturation);
	}
	float matte = 1.0 - key;
	if (matte < 0.02) discard;
	rgb.g = mix(rgb.g, min(rgb.g, max(rgb.r, rgb.b)), key);
	ALBEDO = rgb;
	ALPHA = matte;
}
