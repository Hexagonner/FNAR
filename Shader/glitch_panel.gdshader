/*
	Glitch Effect Shader for CanvasItem/Panel by Yui Kinomoto @arlez80
	Ported & Modified for Godot 4.x (Local Texture Version)
*/

shader_type canvas_item;

// 振動の強さ (진동 세기)
uniform float shake_power = 0.03;
// 振動率 (진동 빈도)
uniform float shake_rate : hint_range( 0.0, 1.0 ) = 0.2;
// 振動速度 (진동 속도)
uniform float shake_speed = 5.0;
// 振動ブロックサイズ (글리치 블록 크기)
uniform float shake_block_size = 30.5;
// 色の分離率 (색상 분리도 / RGB 시프트)
uniform float shake_color_rate : hint_range( 0.0, 1.0 ) = 0.01;

float random( float seed )
{
	return fract( 543.2543 * sin( dot( vec2( seed, seed ), vec2( 3525.46, -54.3415 ) ) ) );
}

void fragment( )
{
	float enable_shift = float(
		random( floor( TIME * shake_speed ) )
	<	shake_rate
	);

	vec2 fixed_uv = UV;
	fixed_uv.x += (
		random(
			( floor( UV.y * shake_block_size ) / shake_block_size )
		+	TIME
		) - 0.5
	) * shake_power * enable_shift;

	// SCREEN_TEXTURE 대신 Panel 자체의 TEXTURE를 사용합니다.
	vec4 pixel_color = texture( TEXTURE, fixed_uv );
	
	// RGB 시프트 효과 적용
	pixel_color.r = mix(
		pixel_color.r
	,	texture( TEXTURE, fixed_uv + vec2( shake_color_rate, 0.0 ) ).r
	,	enable_shift
	);
	pixel_color.b = mix(
		pixel_color.b
	,	texture( TEXTURE, fixed_uv + vec2( -shake_color_rate, 0.0 ) ).b
	,	enable_shift
	);
	
	COLOR = pixel_color;
}