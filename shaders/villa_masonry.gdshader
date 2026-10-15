shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.55,0.52,0.44,1.0);
varying vec3 p;
varying vec3 n;
void vertex(){ p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; n=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
    vec2 uv=vec2(abs(n.z)>0.5?p.x:p.z,p.y);
    float row=floor(uv.y/0.16);
    vec2 grid=vec2(uv.x/0.38+mod(row,2.0)*0.5,uv.y/0.16);
    vec2 edge=min(fract(grid),1.0-fract(grid));
    vec2 aa=max(fwidth(grid),vec2(0.001));
    float mortar=1.0-smoothstep(0.015-aa.x,0.015+aa.x,edge.x)*smoothstep(0.025-aa.y,0.025+aa.y,edge.y);
    float block=fract(sin(dot(floor(grid),vec2(12.9898,78.233)))*43758.5453);
    ALBEDO=mix(stone_color.rgb*(0.86+block*0.24),vec3(0.28,0.27,0.24),mortar*0.65);
    ROUGHNESS=0.94;
}
