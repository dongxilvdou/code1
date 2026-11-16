shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float width_m = 1.48;
uniform float height_m = 2.8;
void fragment() {
	float diagonal = fract((UV.x * width_m + UV.y * height_m) / 0.30);
	float stripe = smoothstep(0.47, 0.50, diagonal) * (1.0 - smoothstep(0.70, 0.73, diagonal));
	ALBEDO = vec3(0.82, 0.70, 0.48);
	ALPHA = stripe * 0.30;
}
