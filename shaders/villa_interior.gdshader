shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://furniture_pack/materials/detail_common.gdshaderinc"
uniform sampler2D plaster_texture : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
vec3 paint(float r,float g,float b) {return pow(vec3(r,g,b),vec3(2.2));}
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    // Sample the room on the outward side of a shared partition.
    vec3 q=world_position+world_normal*.018+vec3(6.0,0.0,6.0);
    bool upper=q.y>2.9;
    float height=mod(q.y+.001,3.0);
    vec3 color=paint(.83,.83,.80);
    bool ceramic=false;
    vec2 tile_size=vec2(.24,.09);
    if(!upper && q.x<5.2) {
        color=paint(.86,.85,.81);
        if(q.z<4.4 && q.x<.3) color=paint(.70,.62,.49);
        if(q.z>4.4 && q.x>5.05) color=paint(.65,.43,.33);
    } else if(!upper && q.z<3.6) {
        color=paint(.86,.89,.87);
        if(height<1.36) {color=paint(.36,.48,.44); ceramic=true;}
    } else if(q.x>6.7 && q.x<9.2 && q.z>3.6 && q.z<6.2) {
        color=paint(.89,.91,.90);
        if(height<2.15) {
            color=upper ? paint(.44,.60,.55) : paint(.38,.56,.64);
            ceramic=true; tile_size=vec2(.12,.24);
        }
    } else if(q.x>6.7 && q.x<9.2 && q.z>=6.2 && q.z<7.5) {
        color=upper ? paint(.77,.73,.65) : paint(.69,.79,.80);
        ceramic=!upper && height<1.25;
    } else if(q.x>=6.7 && q.z>=8.9) {
        color=paint(.88,.86,.81);
        if(q.z<9.1) color=upper ? paint(.68,.43,.32) : paint(.46,.55,.41);
    } else if(upper && q.x<5.2 && q.z<5.4) {
        color=paint(.83,.86,.85);
        if(q.z>5.2) color=paint(.40,.54,.59);
    } else if(upper && q.z<3.6) {
        color=paint(.87,.87,.89);
        if(q.z>3.4) color=paint(.54,.52,.63);
    } else if(upper && q.x<5.2 && q.z>5.4 && q.z<9.0) {
        color=paint(.80,.82,.78);
        if(q.z<5.6 || q.x>5.05) color=paint(.27,.39,.37);
    } else if(upper && q.x>=4.0 && q.x<6.7 && q.z>=9.0) {
        color=paint(.78,.73,.61);
    }
    vec3 data=material_data(plaster_texture,world_position*2.0,world_normal);
    color*=.89+.22*data.r;
    float h=data.g*.0008;
    float rough=.87;
    if(ceramic && abs(world_normal.y)<.5) {
        vec2 p=abs(world_normal.x)>.7 ? world_position.zy : world_position.xy;
        vec2 uv=p/tile_size;
        uv.x+=mod(floor(uv.y),2.0)*.5;
        vec2 edge=min(fract(uv),1.0-fract(uv))*tile_size;
        vec2 aa=max(fwidth(p),vec2(.0002));
        vec2 mask=smoothstep(vec2(.0014)-aa,vec2(.0014)+aa,edge);
        float tile=mask.x*mask.y;
        float variation=fract(sin(dot(floor(uv),vec2(17.3,32.1)))*4313.7);
        color=mix(paint(.65,.67,.64),color*(.88+.24*variation),tile);
        h=data.g*.0003+tile*.0015;
        rough=mix(.9,.30+variation*.16,tile);
    }
    ALBEDO=color;
    ROUGHNESS=rough;
    NORMAL=relief_normal(VERTEX,NORMAL,h);
}
