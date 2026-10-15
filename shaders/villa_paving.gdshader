shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.64,0.62,0.56,1.0);
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 grid=vec2(p.x/0.62+mod(floor(p.z/0.42),2.0)*0.5,p.z/0.42);
    vec2 edge=min(fract(grid),1.0-fract(grid));
    vec2 aa=max(fwidth(grid),vec2(0.0001));
    float seam=1.0-smoothstep(0.010-aa.x,0.010+aa.x,edge.x)*smoothstep(0.014-aa.y,0.014+aa.y,edge.y);
    float tile=fract(sin(dot(floor(grid),vec2(41.43,17.21)))*4517.13);
    ALBEDO=stone_color.rgb*(0.91+tile*0.16)*(1.0-seam*0.24);
    ROUGHNESS=0.90;
}
