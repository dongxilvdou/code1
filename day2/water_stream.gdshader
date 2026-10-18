shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() {
	float flow = sin(UV.y * 24.0 - TIME * 17.0);
	VERTEX.xz *= 1.0 + flow * 0.07;
}
void fragment() {
	float streak = pow(max(0.0,sin(UV.x*18.8496 + UV.y*3.0 - TIME*10.0)),6.0);
	ALBEDO = mix(vec3(.36,.65,.73),vec3(.90,.97,1.0),streak*.7);
	ROUGHNESS = .10;
	SPECULAR = .8;
	ALPHA = .25 + streak * .35;
}
