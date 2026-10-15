shader_type spatial;
render_mode cull_disabled;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 grid=vec2(p.x/0.37+mod(floor(p.z/0.32),2.0)*0.5,p.z/0.32);
    vec2 edge=min(fract(grid),1.0-fract(grid));
    vec2 aa=max(fwidth(grid),vec2(0.001));
    float seam=1.0-smoothstep(0.014-aa.x,0.014+aa.x,edge.x)*smoothstep(0.025-aa.y,0.025+aa.y,edge.y);
    float tile=fract(sin(dot(floor(grid),vec2(41.43,17.21)))*4517.13);
    ALBEDO=mix(vec3(0.060,0.077,0.085)*(0.83+tile*0.34),vec3(0.022,0.027,0.030),seam*0.65);
    ROUGHNESS=0.82;
}
