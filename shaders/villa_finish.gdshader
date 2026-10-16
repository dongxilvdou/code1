shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://furniture_pack/materials/detail_common.gdshaderinc"
uniform vec4 surface_color : source_color=vec4(.7,.6,.45,1.0);
uniform sampler2D detail_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 texture_scale=vec3(1.0);
uniform float roughness=0.75;
uniform float relief=0.001;
uniform bool tiled=false;
uniform vec2 tile_size=vec2(.60);
uniform float grout_width=.004;
uniform bool rotate_grain=false;
varying vec3 world_position;
varying vec3 world_normal;
float tile_noise(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec3 p=world_position;
    if(rotate_grain) p.xz=p.zx;
    vec3 data=material_data(detail_texture,p*texture_scale,world_normal);
    vec3 color=surface_color.rgb*(.62+.76*data.r);
    float h=data.g*relief;
    float r=roughness+(data.b-.75)*.25;
    if(tiled && abs(world_normal.y)>.7) {
        vec2 uv=p.xz/tile_size;
        vec2 edge=min(fract(uv),1.0-fract(uv))*tile_size;
        vec2 aa=max(fwidth(uv)*tile_size,vec2(.0002));
        vec2 fill=smoothstep(vec2(grout_width*.5)-aa,vec2(grout_width*.5)+aa,edge);
        float tile=fill.x*fill.y;
        color*=.94+.12*tile_noise(floor(uv));
        color=mix(surface_color.rgb*.58,color,tile);
        h+=(tile-1.0)*.0016;
        r=mix(.93,r,tile);
    }
    ALBEDO=color;
    ROUGHNESS=clamp(r,.3,.96);
    NORMAL=relief_normal(VERTEX,NORMAL,h);
}
