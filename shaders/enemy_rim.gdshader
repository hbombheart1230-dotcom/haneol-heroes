shader_type canvas_item;
// 적 가독성: 몸 둘레 망령 빛 테두리 + 몸 밝기·대비 올리기 + 군대 색 물들이기.
// 테두리는 주변 8칸의 알파로 찾는다 (텍스처 한 장, 반복문 없음 → 모바일에서 가볍다).
// 수치는 EnemyData(rim_color·rim_width·body_lift·body_contrast·army_tint)에서 온다.

uniform vec4 rim_color : source_color = vec4(0.4, 0.6, 1.0, 0.9);
// 테두리 두께 (텍스처 픽셀).
uniform float rim_width = 2.0;
// 몸 밝기 더하기, 대비 배율, 군대 색 섞는 비율.
uniform float body_lift = 0.0;
uniform float body_contrast = 1.0;
uniform vec4 army_tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;

// 노드 modulate (피격 번쩍임 등). fragment의 COLOR는 텍스처가 이미 곱해져 있을 수 있어 vertex에서 따로 받는다.
varying vec4 node_color;

void vertex() {
	node_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 o = TEXTURE_PIXEL_SIZE * rim_width;
	float n = texture(TEXTURE, UV + vec2(o.x, 0.0)).a + texture(TEXTURE, UV - vec2(o.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, o.y)).a + texture(TEXTURE, UV - vec2(0.0, o.y)).a
		+ texture(TEXTURE, UV + o).a + texture(TEXTURE, UV - o).a
		+ texture(TEXTURE, UV + vec2(o.x, -o.y)).a + texture(TEXTURE, UV + vec2(-o.x, o.y)).a;
	float outside = clamp(n * 0.25, 0.0, 1.0) * (1.0 - tex.a);
	vec3 body = (tex.rgb - 0.5) * body_contrast + 0.5 + body_lift;
	body = mix(body, body * army_tint.rgb * 1.25, tint_mix);
	vec4 col = vec4(clamp(body, 0.0, 1.0), tex.a) * node_color;
	vec4 rim = vec4(rim_color.rgb, rim_color.a * outside * node_color.a);
	// 몸 위에 테두리를 깔고 (몸이 있는 곳은 몸이 이긴다)
	COLOR = mix(rim, col, tex.a);
	COLOR.a = max(col.a, rim.a);
}
