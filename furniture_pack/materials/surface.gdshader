shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://furniture_pack/materials/detail_common.gdshaderinc"
uniform vec4 tint : source_color = vec4(0.6,0.4,0.25,1.0);
uniform float finish = 0.75;
uniform int pattern = 0;
uniform sampler2D wood_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fabric_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_texture : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() { local_pos=VERTEX; local_normal=NORMAL; }
void fragment() {
    vec3 data=vec3(0.5,0.5,finish);
    float bump=0.0;
    if (pattern==1) {
        data=material_data(wood_texture,local_pos*vec3(2.0,0.65,0.65),local_normal);
        bump=0.0012;
    } else if (pattern==2) {
        data=material_data(fabric_texture,local_pos*7.8,local_normal);
        // Threads are about 2 mm apart. Fade their relief below pixel resolution.
        float footprint=max(length(dFdx(local_pos)),length(dFdy(local_pos)))*500.0;
        bump=0.00045*(1.0-smoothstep(.35,1.2,footprint));
    } else if (pattern==3) {
        data=material_data(stone_texture,local_pos*1.8,local_normal);
        bump=0.0005;
    }
    ALBEDO=tint.rgb*(0.65+data.r*0.70);
    ROUGHNESS=clamp(finish+(data.b-0.75)*0.35,0.28,0.98);
    NORMAL=relief_normal(VERTEX,NORMAL,data.g*bump);
}
