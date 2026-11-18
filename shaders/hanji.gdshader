shader_type canvas_item;
// 한지 바닥: 미리 만든 잡음 텍스처(엔진 기본 NoiseTexture2D)를 두 배율로 읽어 종이 섬유 + 먹 번짐을 낸다.
// 픽셀마다 잡음을 계산하지 않아 모바일에서도 가볍다. 임시 아트.

uniform vec4 paper : source_color = vec4(0.92, 0.88, 0.79, 1.0);
uniform vec4 ink : source_color = vec4(0.09, 0.09, 0.11, 1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float fiber_scale = 0.004;
uniform float stain_scale = 0.0006;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos;
	float fiber = texture(noise_tex, vec2(p.x * fiber_scale * 0.25, p.y * fiber_scale * 2.5)).r;
	float stain = smoothstep(0.6, 0.9, texture(noise_tex, p * stain_scale).r);
	vec3 col = paper.rgb * (0.94 + 0.08 * fiber);
	col = mix(col, ink.rgb, stain * 0.14);
	COLOR = vec4(col, 1.0);
}
