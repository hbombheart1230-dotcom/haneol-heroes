shader_type canvas_item;
// 기술 이펙트 입자를 수묵풍으로: 잡음으로 가장자리를 붓처럼 갉아 내고, 가장자리는 먹색으로 물들인다.
// 텍스처·색은 그대로 두고 모양만 다듬어, 어떤 색 입자든 같은 화풍이 된다.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 ink : source_color = vec4(0.09, 0.09, 0.11, 1.0);
// 가장자리 갉기 세기 (0 = 매끈), 먹 물들임 세기, 잡음 배율.
uniform float roughness = 0.35;
uniform float edge_ink = 0.4;
uniform float noise_scale = 0.02;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float n = texture(noise_tex, world_pos * noise_scale).r;
	float cut = smoothstep(roughness * n, roughness * n + 0.12, a);
	float edge = 1.0 - smoothstep(0.3, 0.85, a);
	COLOR.rgb = mix(COLOR.rgb, ink.rgb, edge * edge_ink);
	COLOR.a *= cut;
}
