shader_type spatial;
uniform vec4 grass_dark : source_color = vec4(0.24,0.35,0.13,1.0);
uniform vec4 grass_light : source_color = vec4(0.34,0.45,0.22,1.0);
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v);vec2 f=fract(v);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
    float patches=noise(p.xz*0.60)*0.70+noise(p.xz*3.1)*0.30;
    ALBEDO=mix(grass_dark.rgb,grass_light.rgb,patches);
    ROUGHNESS=1.0;
}
