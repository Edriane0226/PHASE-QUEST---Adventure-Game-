shader_type canvas_item;
render_mode unshaded;
uniform sampler2D permissions : filter_linear, repeat_disable;
uniform sampler2D discovered : filter_linear, repeat_disable;
uniform sampler2D heights : filter_linear, repeat_disable;
uniform sampler2D clouds : filter_linear, repeat_enable;
uniform vec2 extent = vec2(21120.0,10080.0);
uniform float clock = 0.0;
uniform vec2 player_ground = vec2(0.0);
uniform bool reduced_effects = false;
varying vec2 projected;
void vertex() { projected = VERTEX; }
float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx)*.1031);
    q += dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float haze(vec2 p) {
    vec2 i=floor(p), f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec2 ground = projected;
    for (int i=0; i<4; i++) {
        ground = projected + vec2(0.0,texture(heights,ground/extent).r*400.0);
    }
    vec2 uv = ground/extent;
    vec2 permission = texture(permissions,uv).rg;
    vec2 texel=vec2(1.0/220.0,1.0/105.0);
    float known=texture(discovered,uv).r*.4;
    known+=(texture(discovered,uv+vec2(texel.x,0)).r+texture(discovered,uv-vec2(texel.x,0)).r+texture(discovered,uv+vec2(0,texel.y)).r+texture(discovered,uv-vec2(0,texel.y)).r)*.15;
    float personal=1.0-smoothstep(64.0,150.0,distance(ground,player_ground));
    known=max(known,personal*permission.r);
    vec2 drift=vec2(clock*.011,clock*.004);
    float cloud=haze(ground/vec2(1100.0,760.0)+drift);
    if (!reduced_effects) cloud=cloud*.72+haze(ground/vec2(420.0,310.0)-drift*.6)*.28;
    cloud=cloud*.97+texture(clouds,ground/vec2(1300.0,850.0)).a*.03;
    float explore_alpha=(.62+.10*cloud)*(1.0-smoothstep(.05,.95,known));
    float alpha=mix(1.0,explore_alpha,permission.r)*permission.g;
    COLOR=vec4(mix(vec3(.76,.82,.82),vec3(.90,.93,.90),cloud*.55),alpha);
}
