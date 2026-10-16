shader_type canvas_item;
void fragment() {
    float shade=mix(0.87,0.08,smoothstep(0.10,0.82,UV.x));
    shade+=0.08*smoothstep(0.45,1.0,UV.y);
    COLOR=vec4(0.025,0.035,0.028,shade);
}
