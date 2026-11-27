shader_type canvas_item;
// 실시간 3D 적(보스) 그림: 3D 화면 텍스처에 수묵(ink_live.gdshader fragment와 같은 식, 그대로 옮김)을 입힌 뒤
// 그 위에 적 가독성 처리(enemy_rim.gdshader와 같은 식: 망령 빛 테두리·몸 밝기·군대 색·망령 발 사라짐·피격 번쩍임)를 얹는다.
// 테두리는 먹선 바깥에서 찾는다 (이웃 알파를 rim_width + line_px 거리에서). 한 칸짜리 텍스처라 칸 제한이 없다.
// TEXTURE는 함수에 넘기지 않는다 (gl_compatibility) → 모두 fragment 안에.
// 값은 Live3DHeroData.ink와 EnemyData(테두리·망령)에서 온다 (EnemySprite3D가 넣는다).

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

varying vec4 v_mod;
varying float flash_v;  // vertex()에서 쓰므로 그 앞에 (뒤에 두면 SHADER ERROR: Unknown identifier)

void vertex() {
	v_mod = COLOR;
	float fl = step(1.5, COLOR.a);  // 번쩍임은 modulate 알파에 실어 온다 (2 + 양, EnemySprite.FLASH_BASE). 그 동안 알파는 1.
	flash_v = fl * clamp(COLOR.a - 2.0, 0.0, 1.0);
	v_mod = vec4(COLOR.rgb, mix(COLOR.a, 1.0, fl));
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

uniform vec4 rim_color : source_color = vec4(0.4, 0.6, 1.0, 0.9);
uniform float rim_width = 2.0;
uniform float body_lift = 0.0;
uniform float body_contrast = 1.0;
uniform vec4 army_tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;
uniform vec4 ghost_color : source_color = vec4(0.0);
uniform float ghost_body_alpha = 1.0;
uniform float ghost_fade = 0.1;
uniform float ghost_rim_mix = 1.0;
uniform float halo_alpha = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 flash_rim : source_color = vec4(0.0, 0.0, 0.0, 0.0);

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
	vec4 inked = vec4(out_col, clamp(src.a + line_a, 0.0, 1.0));
	// --- 적 테두리·망령 (enemy_rim.gdshader와 같은 식) ---
	vec2 ro = px * (rim_width + line_px);
	float rn = texture(TEXTURE, UV + vec2(ro.x, 0.0)).a + texture(TEXTURE, UV - vec2(ro.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, ro.y)).a + texture(TEXTURE, UV - vec2(0.0, ro.y)).a
		+ texture(TEXTURE, UV + ro).a + texture(TEXTURE, UV - ro).a
		+ texture(TEXTURE, UV + vec2(ro.x, -ro.y)).a + texture(TEXTURE, UV + vec2(-ro.x, ro.y)).a;
	float outside = clamp(rn * 0.25, 0.0, 1.0) * (1.0 - inked.a);
	vec2 ro2 = ro * 2.0;
	float far = texture(TEXTURE, UV + vec2(ro2.x, 0.0)).a + texture(TEXTURE, UV - vec2(ro2.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, ro2.y)).a + texture(TEXTURE, UV - vec2(0.0, ro2.y)).a;
	float halo = clamp(far * 0.5, 0.0, 1.0) * (1.0 - inked.a) * (1.0 - outside) * halo_alpha;
	vec3 rbody = (inked.rgb - 0.5) * body_contrast + 0.5 + body_lift;
	rbody = mix(rbody, rbody * army_tint.rgb * 1.25, tint_mix);
	rbody = mix(rbody, flash_color.rgb, clamp(flash_v, 0.0, 1.0));
	float g = ghost_color.a;
	float foot = smoothstep(1.0 - ghost_fade - 0.12, 1.0, UV.y) * g;
	rbody = mix(rbody, ghost_color.rgb * 1.2, foot * 0.6);
	float ra = inked.a * mix(1.0, ghost_body_alpha, g) * (1.0 - foot * 0.5);
	vec4 rcol = vec4(clamp(rbody, 0.0, 1.0), ra) * v_mod;
	float wave = 0.7 + 0.3 * sin(TIME * 5.0 + UV.y * 60.0 + UV.x * 25.0);
	vec3 rim_rgb = mix(rim_color.rgb, ghost_color.rgb, g * ghost_rim_mix);
	float rim_a = rim_color.a * mix(1.0, wave, g);
	float fr = clamp(flash_v, 0.0, 1.0) * flash_rim.a;
	rim_rgb = mix(rim_rgb, flash_rim.rgb, fr);
	rim_a = max(rim_a, fr);
	vec4 rim = vec4(rim_rgb, max(rim_a * outside, rim_color.a * halo) * v_mod.a);
	COLOR = mix(rim, rcol, ra);
	COLOR.a = max(rcol.a, rim.a);
}
