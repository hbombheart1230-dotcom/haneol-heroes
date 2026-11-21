shader_type canvas_item;
// 그려진 기술 이펙트: 수명(정점 색 알파)이 줄면 잡음 모양대로 먹이 번지듯 사라지고, 사라지는 가장자리는 먹색.
// 정점 색 rgb는 밝기(강화 단계가 오르면 더 밝게).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 ink : source_color = vec4(0.09, 0.09, 0.11, 1.0);
// 수명이 이 비율 아래로 내려가야 번지기 시작한다 (그 전에는 온전한 그림).
uniform float dissolve_from = 0.5;
// 사라지는 가장자리 폭과 먹 물들임 세기.
uniform float edge = 0.12;
uniform float edge_ink = 0.6;
// 잡음 무늬 배율 (클수록 잘게 번진다).
uniform float noise_uv = 1.7;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float n = texture(noise_tex, UV * noise_uv).r;
	float life = clamp(vcol.a / max(dissolve_from, 0.001), 0.0, 1.0) * (1.0 + edge);
	float keep = smoothstep(n, n + 0.04, life);
	float burn = 1.0 - smoothstep(n + 0.04, n + edge, life);
	vec3 col = mix(t.rgb * vcol.rgb, ink.rgb, burn * edge_ink);
	COLOR = vec4(col, t.a * keep);
}
