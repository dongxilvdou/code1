shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Existing procedural textures supply grain and joints; their baked colour
// must not multiply a second coloured albedo and turn white paint olive.
uniform sampler2D detail_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 surface_color : source_color = vec4(0.9, 0.89, 0.86, 1.0);
uniform float texture_scale = 1.0;
uniform float detail_midpoint = 0.6;
uniform float detail_strength = 0.5;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.8;
uniform bool wall_finish = false;
uniform vec4 dado_color : source_color = vec4(0.70,0.73,0.66,1.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 weights = pow(abs(normalize(world_normal)), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    vec3 p = world_position * texture_scale;
    vec3 grain = texture(detail_texture, p.zy).rgb * weights.x;
    grain += texture(detail_texture, p.xz).rgb * weights.y;
    grain += texture(detail_texture, p.xy).rgb * weights.z;
    float value = dot(grain, vec3(0.2126, 0.7152, 0.0722));
    float detail = clamp(1.0 + (value - detail_midpoint) * detail_strength, 0.5, 1.15);
    ALBEDO = surface_color.rgb * detail;
    if(wall_finish && abs(world_normal.y)<0.5 && mod(world_position.y+0.001,3.0)<0.82){
        ALBEDO=dado_color.rgb*detail;
    }
    ROUGHNESS = surface_roughness;
    METALLIC = 0.0;
}
