shader_type spatial;
render_mode diffuse_burley;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
    vec2 p = UV * vec2(2300.0, 1800.0);
    float grain = hash(floor(p));
    float strand = sin(p.x*6.283+sin(p.y*.27)*2.0)*.5+.5;
    ALBEDO = COLOR.rgb * (0.95+grain*.035+strand*.025);
    ROUGHNESS = 0.85 + grain*.08;
    SPECULAR = .25;
    RIM = .16;
    RIM_TINT = .18;
}
