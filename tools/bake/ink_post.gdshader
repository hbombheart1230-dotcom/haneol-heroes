shader_type canvas_item;
// 굽기 후처리: 3D 렌더 프레임(투명 배경)을 수묵풍으로 바꾼다 (오카미식 "3D + 먹선").
// - 바깥 먹선: 알파 경계를 넓혀 붓 굵기로, 잡음으로 굵기를 흔든다
// - 안쪽 먹선: 밝기 경계 (소벨)
// - 담채: 밝기를 3단 먹 농담으로 나누고 원래 색을 옅게 남긴다
// 굽기 도구(bake_sprites.gd)만 쓰며 게임 실행 중에는 쓰지 않는다.

uniform vec4 ink : source_color = vec4(0.07, 0.07, 0.09, 1.0);
uniform vec4 paper : source_color = vec4(0.93, 0.89, 0.80, 1.0);
uniform float line_px = 2.6;
uniform float inner_line = 0.9;
uniform float color_keep = 0.55;
uniform float grain = 0.35;
// 0이면 원래 색 그대로 (먹선만), 1이면 3단 농담 담채 전부. 영웅처럼 무늬가 세밀한 모델은 낮춘다.
uniform float wash_amount = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 src = texture(TEXTURE, UV);
	vec2 cell = UV / px;
	// 붓 굵기 흔들림
	float w = line_px * (0.7 + 0.6 * vnoise(cell * 0.15));
	float reach = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5236;
		vec2 o = vec2(cos(ang), sin(ang)) * w * px;
		reach = max(reach, texture(TEXTURE, UV + o).a);
	}
	float outer = clamp(reach - src.a, 0.0, 1.0);
	// 안쪽 먹선: 밝기 소벨
	float tl = lum(texture(TEXTURE, UV + vec2(-px.x, -px.y)).rgb);
	float t = lum(texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb);
	float tr = lum(texture(TEXTURE, UV + vec2(px.x, -px.y)).rgb);
	float l = lum(texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb);
	float r = lum(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb);
	float bl = lum(texture(TEXTURE, UV + vec2(-px.x, px.y)).rgb);
	float b = lum(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb);
	float br = lum(texture(TEXTURE, UV + vec2(px.x, px.y)).rgb);
	float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
	float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
	float edge = smoothstep(0.25, 0.6, length(vec2(gx, gy))) * inner_line * src.a;
	// 담채: 3단 농담, 경계는 잡음으로 번지게 (먹이 종이에 스민 느낌)
	float n = vnoise(cell * 0.07) - 0.5;
	float L = lum(src.rgb) + n * grain * 0.3;
	float band = mix(0.22, 0.55, smoothstep(0.30, 0.40, L));
	band = mix(band, 0.9, smoothstep(0.58, 0.70, L));
	vec3 wash = mix(ink.rgb, paper.rgb, band);
	vec3 tint = mix(vec3(lum(src.rgb)), src.rgb, 0.75);
	vec3 body = mix(wash, wash * (tint / max(lum(tint), 0.05)), color_keep);
	body = clamp(body, 0.0, 1.0);
	body = mix(src.rgb, body, wash_amount);
	vec3 col = mix(body, ink.rgb, max(edge, 0.0));
	// 바깥 먹선은 마른 붓처럼 끝이 갈라진다
	float dry = step(0.25, vnoise(cell * 0.35 + 7.0));
	float line_a = outer * mix(0.55, 1.0, dry);
	vec3 out_col = mix(ink.rgb, col, src.a / max(src.a + line_a, 0.001));
	COLOR = vec4(out_col, clamp(src.a + line_a, 0.0, 1.0));
}
