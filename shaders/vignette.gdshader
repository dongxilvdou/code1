shader_type canvas_item;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float vignette = smoothstep(0.85, 1.50, length(p));
    COLOR = vec4(0.0, 0.0, 0.0, vignette * 0.08);
}
