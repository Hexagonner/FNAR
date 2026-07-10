shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture;

uniform float exposure    : hint_range(0.5, 2.0) = 1.0;
uniform float contrast    : hint_range(0.5, 2.0) = 1.05;
uniform float saturation  : hint_range(0.0, 2.0) = 0.9;

uniform bool  enable_pixelate = true;
uniform float pixel_factor    : hint_range(0.5, 6.0) = 3.0;

uniform bool  enable_posterize = true;
uniform float color_levels     : hint_range(2.0, 16.0) = 16.0;
uniform float dither_strength  : hint_range(0.0, 1.0) = 0.35;

uniform float chrom_aberration : hint_range(0.0, 2.0) = 0.07;
uniform float vignette_strength: hint_range(0.0, 2.0) = 1.0;
uniform float grain_strength   : hint_range(0.0, 1.0) = 0.2;

uniform vec3  tint_color = vec3(0.95, 1.03, 0.9);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.15;

uniform vec2  viewport_size_override = vec2(0.0);

/// 저사양 모드. true면 픽셀화/포스터화/그레인/디더링 등 비싼 연산을 건너뛰고
/// 톤 매핑/비네트/틴트만 적용해 비용을 크게 줄인다.
/// scene script에서 GlobalSetting.low_spec_mode 값으로 갱신한다.
uniform bool  low_spec_mode = false;

void fragment(){
    if (low_spec_mode) {
        // 저사양 경로: 색 보정 + 비네트 + 틴트만 적용 (1회 샘플).
        vec2 uv_l = SCREEN_UV;
        vec3 col_l = texture(screen_tex, uv_l).rgb;
        col_l *= exposure;
        col_l = mix(col_l, col_l * tint_color, tint_strength);
        col_l = (col_l - 0.5) * contrast + 0.5;
        // 채도 (인라인 근사: 채널별 lerp, to_hsv/to_rgb 변환 회피)
        float luma_l = dot(col_l, vec3(0.2126, 0.7152, 0.0722));
        col_l = mix(vec3(luma_l), col_l, saturation);
        // 비네트
        vec2 v_l = uv_l - 0.5;
        float vd_l = dot(v_l, v_l);
        float vig_l = smoothstep(0.5, 0.9, vd_l * 2.0) * vignette_strength;
        col_l *= clamp(1.0 - vig_l, 0.0, 1.0);
        COLOR = vec4(clamp(col_l, 0.0, 1.0), 1.0);
    } else {
        vec2 uv = SCREEN_UV;

        vec2 px = SCREEN_PIXEL_SIZE;
        if (viewport_size_override.x > 0.0 && viewport_size_override.y > 0.0){
            px = 1.0 / viewport_size_override;
        }

        if (enable_pixelate){
            vec2 step_uv = px * pixel_factor;
            uv = floor(uv / step_uv) * step_uv + step_uv * 0.5;
        }

        // 크로마틱 어버레이션. chrom_aberration가 0이면 단일 샘플로 단축.
        vec3 col;
        if (chrom_aberration > 0.001) {
            vec2 center = vec2(0.5);
            vec2 dir = uv - center;
            float dist = length(dir);
            float ca = chrom_aberration * dist * dist;
            col.r = texture(screen_tex, uv + dir * ( ca)).r;
            col.g = texture(screen_tex, uv                    ).g;
            col.b = texture(screen_tex, uv - dir * ( ca)).b;
            // 비네트 거리 계산을 재사용
            col *= exposure;
            col = mix(col, col * tint_color, tint_strength);
            if (enable_posterize){
                vec2 frag_xy = floor(uv / px);
                // bayer4x4 인덱스 배열 대신 정수 mod 기반 1D dither (저렴)
                float b = fract(sin(dot(mod(frag_xy, 4.0), vec2(12.9898, 78.233))) * 43758.5453);
                vec3 q = floor(col * color_levels + b * dither_strength);
                col = q / (color_levels - 1.0);
            }
            // 톤 매핑: HSV 왕복 대신 인라인 lerp
            col = (col - 0.5) * contrast + 0.5;
            float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
            col = mix(vec3(lum), col, saturation);
            float vignette = smoothstep(0.5, 0.9, dist) * vignette_strength;
            col *= clamp(1.0 - vignette, 0.0, 1.0);
        } else {
            col = texture(screen_tex, uv).rgb;
            col *= exposure;
            col = mix(col, col * tint_color, tint_strength);
            if (enable_posterize){
                vec2 frag_xy = floor(uv / px);
                float b = fract(sin(dot(mod(frag_xy, 4.0), vec2(12.9898, 78.233))) * 43758.5453);
                vec3 q = floor(col * color_levels + b * dither_strength);
                col = q / (color_levels - 1.0);
            }
            col = (col - 0.5) * contrast + 0.5;
            float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
            col = mix(vec3(lum), col, saturation);
            vec2 v = uv - 0.5;
            float vd = dot(v, v);
            float vig = smoothstep(0.5, 0.9, vd * 2.0) * vignette_strength;
            col *= clamp(1.0 - vig, 0.0, 1.0);
        }

        // 그레인 (cost 가드)
        if (grain_strength > 0.001) {
            float n = fract(sin(dot(floor(uv/px), vec2(12.9898, 78.233)) + TIME * 37.0) * 43758.5453);
            col += (n - 0.5) * (px.x + px.y) * 2.0 * grain_strength;
        }

        COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
    }
}
