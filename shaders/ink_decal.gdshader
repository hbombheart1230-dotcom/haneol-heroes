shader_type canvas_item;
// 그려진 기술 이펙트: 수명(정점 색 알파)이 줄면 잡음 모양대로 먹이 번지듯 사라지고, 사라지는 가장자리는 먹색.
// 떠 있는 동안 그림 속이 움직인다 (디아블로 3식: 잡음을 흘려 UV를 흔듦 = 일렁임, 수명에 따라 가운데가 감김 = 흐름).
// 정점 색 채널: r = 밝기 (강화 단계), g = 일렁임 세기 (0~1), b = 감김 (라디안 / 4), a = 남은 수명.
// 셋 다 0이면 예전과 같은 정지 그림 (g = b = 0).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 ink : source_color = vec4(0.09, 0.09, 0.11, 1.0);
// 수명이 이 비율 아래로 내려가야 번지기 시작한다 (그 전에는 온전한 그림).
uniform float dissolve_from = 0.5;
// 사라지는 가장자리 폭과 먹 물들임 세기.
uniform float edge = 0.12;
uniform float edge_ink = 0.6;
// 잡음 무늬 배율 (클수록 잘게 번진다).
uniform float noise_uv = 1.7;
// 일렁임: 흔드는 폭(UV), 잡음이 흐르는 속도(초당 UV), 잡음 크기 배율.
uniform float flicker_amp = 0.035;
uniform vec2 flicker_speed = vec2(0.35, -0.22);
uniform float flicker_scale = 1.3;
// true면 정점 색 rgb를 그대로 색으로 곱한다 (베인 자국·바늘처럼 색을 입히는 붓 그림, 움직임 없음).
uniform bool tinted = false;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float twist = tinted ? 0.0 : vcol.b * 4.0;
	float flick = tinted ? 0.0 : vcol.g;
	if (twist > 0.0) {
		// 감김: 가운데일수록 많이 돌아 (수명이 줄수록 더) 소용돌이처럼 흘러 들어간다.
		vec2 c = uv - vec2(0.5);
		float r = length(c);
		float a = twist * (1.0 - clamp(vcol.a, 0.0, 1.0)) * (1.0 - smoothstep(0.0, 0.55, r));
		float s = sin(a);
		float co = cos(a);
		uv = vec2(c.x * co - c.y * s, c.x * s + c.y * co) + vec2(0.5);
	}
	if (flick > 0.0) {
		// 잡음은 흑백이라 x·y를 서로 다른 자리에서 읽는다 (저사양: 두 번만 읽음).
		vec2 p = uv * flicker_scale + TIME * flicker_speed;
		vec2 n = vec2(texture(noise_tex, p).r, texture(noise_tex, p.yx * 0.83 + vec2(0.37, 0.71)).r);
		uv += (n - 0.5) * flicker_amp * flick;
	}
	vec4 t = texture(TEXTURE, uv);
	float n = texture(noise_tex, UV * noise_uv).r;
	float life = clamp(vcol.a / max(dissolve_from, 0.001), 0.0, 1.0) * (1.0 + edge);
	float keep = smoothstep(n, n + 0.04, life);
	float burn = 1.0 - smoothstep(n + 0.04, n + edge, life);
	vec3 tint = tinted ? vcol.rgb : vec3(vcol.r);
	vec3 col = mix(t.rgb * tint, ink.rgb, burn * edge_ink);
	COLOR = vec4(col, t.a * keep);
}
