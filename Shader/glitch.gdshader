shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float brightness : hint_range(0.0,2.0) = 0.75;
uniform float contrast : hint_range(0.0,2.0) = 1.1;

uniform float vignette_strength : hint_range(0.0,2.0) = 1.2;

uniform float grain_strength : hint_range(0.0,0.2) = 0.04;
uniform float noise_strength : hint_range(0.0,0.2) = 0.02;

uniform float scanline_strength : hint_range(0.0,0.2) = 0.05;
uniform float scanline_density = 900.0;

uniform float chroma_offset : hint_range(0.0,0.01) = 0.002;

uniform float shake_strength : hint_range(0.0,0.01) = 0.0015;

uniform float glitch_strength : hint_range(0.0,1000) = 0.02;
uniform float glitch_speed = 8.0;

uniform float flicker_strength : hint_range(0.0,0.1) = 0.05;



float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}



float value_noise(vec2 uv){

    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float a = rand(i);
    float b = rand(i + vec2(1.0,0.0));
    float c = rand(i + vec2(0.0,1.0));
    float d = rand(i + vec2(1.0,1.0));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a,b,u.x) +
           (c-a)*u.y*(1.0-u.x) +
           (d-b)*u.x*u.y;
}



vec2 screen_shake(vec2 uv){

    float sx = sin(TIME * 25.0) * shake_strength;
    float sy = cos(TIME * 18.0) * shake_strength;

    return uv + vec2(sx, sy);
}



vec2 glitch_offset(vec2 uv){

    float line = floor(uv.y * 40.0);

    float n = rand(vec2(line, TIME * glitch_speed));

    float offset = step(0.96, n) * glitch_strength;

    uv.x += offset * sin(TIME * 30.0);

    return uv;
}



vec3 chromatic(vec2 uv){

    vec2 off = vec2(chroma_offset,0.0);

    float r = texture(screen_tex, uv + off).r;
    float g = texture(screen_tex, uv).g;
    float b = texture(screen_tex, uv - off).b;

    return vec3(r,g,b);
}



float vignette(vec2 uv){

    vec2 pos = uv - 0.5;

    float len = length(pos);

    return smoothstep(vignette_strength,0.4,len);
}



float scanline(vec2 uv){

    return sin(uv.y * scanline_density) * scanline_strength;
}



float grain(vec2 uv){

    float g = rand(uv * TIME * 20.0);

    return (g - 0.5) * grain_strength;
}



float static_noise(vec2 uv){

    float n = value_noise(uv * 300.0 + TIME * 5.0);

    return (n - 0.5) * noise_strength;
}



float flicker(){

    return sin(TIME * 12.0) * flicker_strength;
}



vec3 apply_color(vec3 col){

    col *= brightness;

    col = (col - 0.5) * contrast + 0.5;

    return col;
}



void fragment(){

    vec2 uv = SCREEN_UV;

    uv = screen_shake(uv);

    uv = glitch_offset(uv);

    vec3 col = chromatic(uv);

    col *= vignette(uv);

    col -= scanline(uv);

    col += grain(uv);

    col += static_noise(uv);

    col += flicker();

    col = apply_color(col);

    COLOR = vec4(col,1.0);
}