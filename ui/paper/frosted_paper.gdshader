shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 panel_size = vec2(200.0, 100.0);
uniform vec4 paper_tint : source_color = vec4(0.9608, 0.9373, 0.8745, 0.55);
uniform float blur_pixels = 6.0;
uniform float corner_radius = 8.0;

void fragment() {
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, log2(max(1.0, blur_pixels))).rgb;
	vec2 half_size = panel_size * 0.5;
	float radius = min(corner_radius, min(half_size.x, half_size.y));
	vec2 q = abs(UV * panel_size - half_size) - half_size + vec2(radius);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float coverage = 1.0 - smoothstep(-0.8, 0.8, distance_to_edge);
	COLOR = vec4(mix(blurred, paper_tint.rgb, paper_tint.a), coverage * COLOR.a);
}
