shader_type canvas_item;
// 바닥 그림 색 보정 (StageLook 또는 StageTheme.floor_value·floor_saturation).
// 순서: 채도 → 명도 배율 → 대비(pivot 기준) → 명암에 따라 어둠색·밝은색 물들이기.
// 기본값이면 원래 그림 그대로. 반복문 없음. 결 층(detail_tex, 회색 0.5 = 그대로)이 있으면 그림에 곱한다 (사진 재질의 결만).
uniform float value_mult = 1.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float pivot = 0.3;
// 어두운 곳 / 밝은 곳에 입힐 색 (밝기는 유지하고 색만 바꾼다). tint_mix 0이면 없음.
uniform vec4 shadow_tint : source_color = vec4(1.0);
uniform vec4 light_tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;
// 물들이기에서 어둠색 → 밝은색으로 넘어가는 밝기.
uniform float tint_split = 0.3;

// 결 층: 지도 크기(px)를 detail_px 한 칸으로 반복. detail_strength 0이면 없음.
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float detail_strength = 0.0;
uniform vec2 map_px = vec2(1.0);
uniform float detail_px = 512.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (detail_strength > 0.0) {
		float d = texture(detail_tex, UV * map_px / detail_px).r;
		c.rgb *= 1.0 + (d - 0.5) * 2.0 * detail_strength;
	}
	float y = dot(c.rgb, LUMA);
	c.rgb = mix(vec3(y), c.rgb, saturation) * value_mult;
	c.rgb = max((c.rgb - pivot) * contrast + pivot, vec3(0.0));
	float y2 = dot(c.rgb, LUMA);
	vec3 tint = mix(shadow_tint.rgb, light_tint.rgb, smoothstep(tint_split * 0.4, tint_split * 1.8, y2));
	vec3 toned = tint * (y2 / max(dot(tint, LUMA), 0.02));
	c.rgb = mix(c.rgb, toned, tint_mix);
	COLOR = c;
}
