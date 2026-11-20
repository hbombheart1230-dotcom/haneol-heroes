shader_type canvas_item;
// 적 가독성: 몸 둘레 망령 빛 테두리 + 몸 밝기·대비 올리기 + 군대 색 물들이기.
// 테두리는 주변 8점의 알파로 찾는다 (반복문 없음 → 모바일에서 가볍다). 시트의 지금 칸 밖은 읽지 않는다.
// 수치는 EnemyData(rim_color·rim_width·body_lift·body_contrast·army_tint)에서 온다.

uniform vec4 rim_color : source_color = vec4(0.4, 0.6, 1.0, 0.9);
// 테두리 두께 (텍스처 픽셀).
uniform float rim_width = 2.0;
// 몸 밝기 더하기, 대비 배율, 군대 색 섞는 비율.
uniform float body_lift = 0.0;
uniform float body_contrast = 1.0;
uniform vec4 army_tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;
// 구운 시트 한 칸 크기(px). 이웃 칸(다른 프레임)의 알파를 읽지 않도록 지금 칸 안에서만 본다. 0이면 제한 없음.
uniform float cell_px = 0.0;
// 피격 흰 번쩍임 (적마다 다름 → instance uniform, EnemySprite가 매 프레임 넣는다). 0이면 원래 색, 1이면 흰색.
instance uniform float flash = 0.0;

// 노드 modulate (피격 번쩍임 등). fragment의 COLOR는 텍스처가 이미 곱해져 있을 수 있어 vertex에서 따로 받는다.
varying vec4 node_color;

void vertex() {
	node_color = COLOR;
}

// lo~hi 칸 안이면 1, 밖이면 0 (이웃 프레임을 읽지 않음). TEXTURE는 함수에 넘기지 않는다 (gl_compatibility).
float in_cell(vec2 uv, vec2 lo, vec2 hi) {
	return step(lo.x, uv.x) * step(lo.y, uv.y) * (1.0 - step(hi.x, uv.x)) * (1.0 - step(hi.y, uv.y));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 o = TEXTURE_PIXEL_SIZE * rim_width;
	vec2 lo = vec2(0.0);
	vec2 hi = vec2(1.0);
	if (cell_px > 0.0) {
		vec2 cell = TEXTURE_PIXEL_SIZE * cell_px;
		lo = floor(UV / cell) * cell;
		hi = lo + cell;
	}
	vec2 p1 = UV + vec2(o.x, 0.0);
	vec2 p2 = UV - vec2(o.x, 0.0);
	vec2 p3 = UV + vec2(0.0, o.y);
	vec2 p4 = UV - vec2(0.0, o.y);
	vec2 p5 = UV + o;
	vec2 p6 = UV - o;
	vec2 p7 = UV + vec2(o.x, -o.y);
	vec2 p8 = UV + vec2(-o.x, o.y);
	float n = texture(TEXTURE, p1).a * in_cell(p1, lo, hi) + texture(TEXTURE, p2).a * in_cell(p2, lo, hi)
		+ texture(TEXTURE, p3).a * in_cell(p3, lo, hi) + texture(TEXTURE, p4).a * in_cell(p4, lo, hi)
		+ texture(TEXTURE, p5).a * in_cell(p5, lo, hi) + texture(TEXTURE, p6).a * in_cell(p6, lo, hi)
		+ texture(TEXTURE, p7).a * in_cell(p7, lo, hi) + texture(TEXTURE, p8).a * in_cell(p8, lo, hi);
	float outside = clamp(n * 0.25, 0.0, 1.0) * (1.0 - tex.a);
	vec3 body = (tex.rgb - 0.5) * body_contrast + 0.5 + body_lift;
	body = mix(body, body * army_tint.rgb * 1.25, tint_mix);
	body = mix(body, vec3(1.0), clamp(flash, 0.0, 1.0));
	vec4 col = vec4(clamp(body, 0.0, 1.0), tex.a) * node_color;
	vec4 rim = vec4(rim_color.rgb, rim_color.a * outside * node_color.a);
	// 몸 위에 테두리를 깔고 (몸이 있는 곳은 몸이 이긴다)
	COLOR = mix(rim, col, tex.a);
	COLOR.a = max(col.a, rim.a);
}
