shader_type canvas_item;
// 그림 모양만 남긴 한 색 실루엣 (회피 무적 금빛 테두리, EvadeRim): 색은 그리는 쪽 modulate, 모양은 텍스처 알파.

void fragment() {
	COLOR = vec4(COLOR.rgb, COLOR.a * texture(TEXTURE, UV).a);
}
