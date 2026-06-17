shader_type canvas_item;

uniform float amount = 40.0;
uniform float uv_amount:hint_range(0.0 ,1.0)  = 0.05;
void fragment() {
	vec2 uv = UV * uv_amount;
	float a = fract(sin(dot(uv, vec2(12.9898, 78.233) * TIME)) * 438.5453) * 1.9;
	COLOR.a *= clamp(pow(a, amount), 0, 1);
}