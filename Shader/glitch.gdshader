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

/// 저사양 모드. true면 value_noise/grain/scanline/chroma를 비활성화하고
/// 색 보정과 비네트만 적용해 비용을 크게 줄인다.
uniform bool low_spec_mode = false;

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
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



float vignette(vec2 uv){

    vec2 pos = uv - 0.5;

    float len = length(pos);

    return smoothstep(vignette_strength,0.4,len);
}



vec3 apply_color(vec3 col){

    col *= brightness;

    col = (col - 0.5) * contrast + 0.5;

    return col;
}



void fragment(){
    if (low_spec_mode) {
        // 저사양 경로: 단일 샘플 + 색보정 + 비네트만.
        vec3 col = texture(screen_tex, SCREEN_UV).rgb;
        col = apply_color(col);
        col *= vignette(SCREEN_UV);
        COLOR = vec4(col, 1.0);
    } else {
        vec2 uv = SCREEN_UV;

        uv = screen_shake(uv);

        uv = glitch_offset(uv);

        // chroma_offset이 0이면 단일 샘플로 단축.
        vec3 col;
        if (chroma_offset > 0.0001) {
            vec2 off = vec2(chroma_offset, 0.0);
            col.r = texture(screen_tex, uv + off).r;
            col.g = texture(screen_tex, uv).g;
            col.b = texture(screen_tex, uv - off).b;
        } else {
            col = texture(screen_tex, uv).rgb;
        }

        col *= vignette(uv);

        if (scanline_strength > 0.0001) {
            col -= sin(uv.y * scanline_density) * scanline_strength;
        }
        if (grain_strength > 0.0001) {
            float g = rand(uv * TIME * 20.0);
            col += (g - 0.5) * grain_strength;
        }
        // noise_strength는 원래 value_noise (4회 hash) 호출 → 비용 큼.
        // 저사양 모드가 아니면 cost 감당을 위해 단순 hash로 대체.
        if (noise_strength > 0.0001) {
            float n = rand(uv * 300.0 + vec2(TIME * 5.0));
            col += (n - 0.5) * noise_strength;
        }
        if (flicker_strength > 0.0001) {
            col += sin(TIME * 12.0) * flicker_strength;
        }

        col = apply_color(col);

        COLOR = vec4(col,1.0);
    }
}