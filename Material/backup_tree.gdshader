shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled,
            diffuse_burley, specular_schlick_ggx;
/* ===== Material ===== */
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color;
uniform sampler2D texture_normal;
uniform sampler2D texture_metallic;
uniform sampler2D texture_roughness;

uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform float specular = 0.5;
uniform float normal_scale = 1.0;

/* ===== Open ===== */
uniform float open_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool open_from_left = true;
uniform float edge_softness : hint_range(0.0, 0.2) = 0.03;

/* ===== Sway ===== */
uniform float wave_strength = 0.02;
uniform float wave_speed = 1.2;
uniform float wave_frequency = 8.0;

uniform float noise_strength = 0.012;
uniform float noise_speed = 0.3;
uniform float noise_scale = 3.0;

/* ===== Noise ===== */
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(hash(i), hash(i + vec2(1,0)), u.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x),
        u.y
    );
}

/* ===== Vertex ===== */
void vertex() {
    float vertical = 1.0 - UV.y;          // 0 = 위, 1 = 아래
    float hang_mask = pow(vertical, 1.8); // 위 고정

    float wave = sin(vertical * wave_frequency + TIME * wave_speed);
    float n = noise(vec2(vertical * noise_scale, TIME * noise_speed));
    n = n * 2.0 - 1.0;

    float sway = (wave * wave_strength + n * noise_strength) * hang_mask;

    VERTEX += NORMAL * sway;
}

/* ===== Fragment ===== */
void fragment() {
    vec2 uv = UV;

    /* ---------- 열림 마스크 ---------- */
    float h = open_from_left ? uv.x : (1.0 - uv.x);

    // open_amount = 0 → 다 보임
    // open_amount = 1 → 완전 개방
    float curtain_mask = smoothstep(open_amount, open_amount + edge_softness, h);

    ALPHA = curtain_mask;

    /* ---------- Material ---------- */
    ALBEDO = albedo.rgb * texture(texture_albedo, uv).rgb;
    METALLIC = metallic * texture(texture_metallic, uv).r;
    ROUGHNESS = roughness * texture(texture_roughness, uv).r;

    NORMAL_MAP = texture(texture_normal, uv).rgb;
    NORMAL_MAP_DEPTH = normal_scale;

    SPECULAR = specular;
}
