// Triplanar linear material data and a view-space surface-gradient normal.
vec3 material_data(sampler2D tex, vec3 p, vec3 n) {
    vec3 w = pow(abs(n), vec3(6.0));
    w /= max(w.x+w.y+w.z, 0.0001);
    return texture(tex,p.zy).rgb*w.x + texture(tex,p.xz).rgb*w.y + texture(tex,p.xy).rgb*w.z;
}
vec3 relief_normal(vec3 position, vec3 normal, float height) {
    vec3 dx = dFdx(position), dy = dFdy(position);
    vec3 a = cross(dy,normal), b = cross(normal,dx);
    float determinant = dot(dx,a);
    vec3 gradient = (a*dFdx(height)+b*dFdy(height))*sign(determinant)/max(abs(determinant),0.000001);
    // Bound shallow-view gradients so fine relief never crawls at cat-eye height.
    return normalize(normal-clamp(gradient,vec3(-0.45),vec3(0.45)));
}
