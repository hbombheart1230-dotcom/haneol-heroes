shader_type canvas_item;
// 바닥 그림 명도·채도 낮추기 (하데스식 대비: 바닥은 어둡고 탁하게, 캐릭터·효과가 뜨게). StageTheme.floor_value·floor_saturation.
uniform float value_mult = 1.0;
uniform float saturation = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float y = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	c.rgb = mix(vec3(y), c.rgb, saturation) * value_mult;
	COLOR = c;
}
