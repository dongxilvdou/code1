shader_type spatial;
// Metre-scaled ceramic grout, aged plaster and a pale hospital-green datum.
uniform vec4 paint: source_color = vec4(.78,.81,.77,1.);
uniform sampler2D detail_texture: repeat_enable, filter_linear_mipmap;
uniform bool floor_surface = false;
uniform bool ceiling_surface = false;
varying vec3 world;
varying vec3 normal_world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	vec2 uv = world.xz;
	if(!floor_surface && !ceiling_surface){uv=abs(normal_world.x)>.5?world.zy:world.xy;}
	vec2 tiles=uv/(floor_surface?.45:.30);
	vec2 edge=min(fract(tiles),1.-fract(tiles));
	float seam=1.-smoothstep(.008,.018,min(edge.x,edge.y));
	float grain=texture(detail_texture,uv*.83).r;
	float age=texture(detail_texture,uv*.14+vec2(.21)).r;
	vec3 col=paint.rgb*(.88+.20*grain);
	float height=world.y+2.7;
	if(!ceiling_surface && (floor_surface || height<1.26)){
		col=mix(col,vec3(.28,.33,.30),seam*.53);
		col*=.96+.04*sin(floor(tiles.x)*7.+floor(tiles.y)*31.);
	}
	if(!floor_surface && !ceiling_surface){
		if(height>1.20 && height<1.28)col=vec3(.27,.38,.35);
		col=mix(col,vec3(.28,.32,.28),max(0.,.16-height)*1.6*(.5+age));
	}
	ALBEDO=col;ROUGHNESS=floor_surface?.59:.88;
}
