shader_type canvas_item;
// 그림 모양만 남긴 한 색 실루엣 (회피 무적 금빛 테두리, EvadeRim): 색은 그리는 쪽 modulate, 모양은 텍스처 알파.
// fragment의 COLOR는 이미 텍스처 색이 곱해져 있어 (어두워짐) vertex에서 색만 따로 받는다.

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = vec4(tint.rgb, tint.a * texture(TEXTURE, UV).a);
}
