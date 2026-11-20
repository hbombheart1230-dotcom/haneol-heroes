shader_type spatial;
// 굽기 전에 모델 색을 다시 칠한다: 원래 텍스처의 밝기에 따라 군대 색 4단(어둠·중간·밝음·빛)으로 옮긴다.
// 빛·그림자는 3D 조명이 그대로 얹어져 입체감이 남는다.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 c0 : source_color = vec4(0.08, 0.1, 0.18, 1.0);
uniform vec4 c1 : source_color = vec4(0.42, 0.14, 0.12, 1.0);
uniform vec4 c2 : source_color = vec4(0.66, 0.52, 0.29, 1.0);
uniform vec4 c3 : source_color = vec4(0.91, 0.86, 0.75, 1.0);
uniform float mix_amount = 0.85;
uniform float contrast = 1.25;
uniform float roughness_v = 0.55;
uniform float specular_v = 0.45;

vec3 ramp(float l) {
	if (l < 0.33) return mix(c0.rgb, c1.rgb, l / 0.33);
	if (l < 0.66) return mix(c1.rgb, c2.rgb, (l - 0.33) / 0.33);
	return mix(c2.rgb, c3.rgb, (l - 0.66) / 0.34);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a < 0.4) {
		discard;
	}
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	ALBEDO = mix(t.rgb, ramp(l), mix_amount);
	ROUGHNESS = roughness_v;
	SPECULAR = specular_v;
}
