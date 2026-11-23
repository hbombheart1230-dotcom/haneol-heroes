extends GdUnitTestSuite
## 무대 조명 (StageLook): 바닥 색 보정 셰이더 값, 빛 웅덩이 위치, 영웅 발밑 빛.
## 공통 가독성: 적 테두리 바깥 번짐, 평타 검기 크기·밝은 심.

const HANSAN := preload("res://data/stages/hansan_1592.tres")
const BRAZIER := preload("res://assets/props/hansan/brazier.png")
const CANNON := preload("res://assets/props/hansan/cannon.png")


func _look() -> StageLook:
	var l := StageLook.new()
	l.lit_props = PackedStringArray(["brazier"])
	l.prop_light_radius = 300.0
	l.prop_light_offset = Vector2(0, -20)
	l.pools_per_mpx = 1.0
	l.pool_spacing = 300.0
	return l


func test_prop_lights_only_on_named_props() -> void:
	var tex: Array[Texture2D] = [BRAZIER, CANNON]
	var items := [[Vector2(100, 200), 2, 0.5, 0], [Vector2(-300, 0), 2, 0.5, 1], [Vector2(0, 0), 0, 30.0, 1.0]]
	var l := _look()
	l.pools_per_mpx = 0.0
	var out := LightPools.place(l, Rect2(-1000, -1000, 2000, 2000), items, tex, 1)
	assert_int(out.size()).is_equal(1)
	assert_vector(out[0][0]).is_equal(Vector2(100, 190))  # 소품 배율만큼 불꽃 쪽으로
	assert_float(out[0][1]).is_equal(300.0)


func test_pools_follow_density_spacing_and_seed() -> void:
	var l := _look()
	var r := Rect2(-1000, -1500, 2000, 3000)
	var tex: Array[Texture2D] = []
	var a := LightPools.place(l, r, [], tex, 7)
	var b := LightPools.place(l, r, [], tex, 7)
	assert_int(a.size()).is_equal(6)  # 6 Mpx × 1
	for i in a.size():
		assert_vector(a[i][0]).is_equal(b[i][0])  # 판마다 같은 자리
		assert_bool(r.has_point(a[i][0])).is_true()
		for k in range(i + 1, a.size()):
			assert_float((a[i][0] as Vector2).distance_to(a[k][0])).is_greater_equal(l.pool_spacing)


func test_arena_grades_floor_and_lays_lights_from_look() -> void:
	var arena: Arena = auto_free(Arena.new())
	add_child(arena)
	var st := HANSAN.duplicate() as StageTheme
	var l := _look()
	l.contrast = 1.8
	l.tint_mix = 0.7
	l.hero_light_color = Color(1, 0.8, 0.5, 0.3)
	st.look = l
	arena.apply_theme(st)
	var m := arena.map.material as ShaderMaterial
	assert_float(float(m.get_shader_parameter("contrast"))).is_equal(1.8)
	assert_float(float(m.get_shader_parameter("tint_mix"))).is_equal_approx(0.7, 0.001)
	assert_bool(arena.lights.visible).is_true()
	assert_int(arena.lights.pools.size()).is_greater(0)
	assert_int((arena.lights.material as CanvasItemMaterial).blend_mode).is_equal(CanvasItemMaterial.BLEND_MODE_ADD)
	var hero: Node2D = auto_free(Node2D.new())
	add_child(hero)
	hero.global_position = Vector2(123, 45)
	arena.lights.follow(hero)
	await get_tree().process_frame
	assert_bool(arena.lights.hero_glow.visible).is_true()
	assert_vector(arena.lights.hero_glow.global_position).is_equal(Vector2(123, 45))


func test_no_look_keeps_old_floor_and_no_lights() -> void:
	var arena: Arena = auto_free(Arena.new())
	add_child(arena)
	var st := (load("res://data/stages/manchuria_395.tres") as StageTheme).duplicate() as StageTheme
	st.look = null  # 조명 없는 무대 (예전 방식)
	arena.apply_theme(st)
	assert_bool(arena.lights.visible).is_false()
	assert_int(arena.lights.pools.size()).is_equal(0)
	assert_bool(arena.lights.hero_glow.is_processing()).is_false()


## 네 무대 모두 한산 기준: 조명(look)·확대 1.09·비네트, 바닥은 어둡지만 명암 폭이 있고 색이 있다.
## 여기서는 지도 그림 전체(가장자리 포함)를 보정만 해서 잰다: 비네트·빛 웅덩이가 없어 실제 화면보다 밝고 덜 진하다.
## 실제 화면 값(한산 기준 편차 ≈ 0.15, 상위 5% ≈ 0.52)은 tools/shots/look_shot.gd + measure_look.py로 잰다.
## 그리고 무대마다 색이 한눈에 다르다 (평균 색 색상 차 ≥ 0.08).
const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func test_every_stage_has_look_zoom_and_vignette() -> void:
	for id in STAGES:
		var st: StageTheme = load("res://data/stages/%s.tres" % id)
		assert_object(st.look).override_failure_message(id).is_not_null()
		assert_float(st.camera_zoom).override_failure_message(id).is_equal_approx(1.09, 0.001)
		assert_float(st.vignette).override_failure_message(id).is_greater(0.0)


## 초충도만 "밝은 한지 세계" (사용자 결정: 그림 속 세상, 네 무대 중 혼자 밝게). 나머지는 어두운 기준.
const BRIGHT_STAGES := ["chochungdo"]


func test_every_floor_is_contrasty_coloured_and_distinct() -> void:
	var hues: Array[float] = []
	var means: Array[float] = []
	for id in STAGES:
		var s := FloorGrade.stats(load("res://data/stages/%s.tres" % id))
		if BRIGHT_STAGES.has(id):
			assert_float(s[0]).override_failure_message("%s mean (bright)" % id).is_between(0.45, 0.95)
		else:
			assert_float(s[0]).override_failure_message("%s mean" % id).is_less_equal(0.45)
		assert_float(s[1]).override_failure_message("%s std" % id).is_greater_equal(0.06)
		assert_float(s[2]).override_failure_message("%s sat" % id).is_greater_equal(0.25)
		hues.append((s[3] as Color).h)
		means.append(s[0])
	for i in hues.size():
		for k in range(i + 1, hues.size()):
			var d := absf(hues[i] - hues[k])
			# 한눈에 구분: 색상이 다르거나 (≥ 0.08) 밝기가 확연히 다르다 (≥ 0.2, 밝은 한지 초충도)
			var apart := minf(d, 1.0 - d) >= 0.08 or absf(means[i] - means[k]) >= 0.2
			assert_bool(apart).override_failure_message("%s vs %s" % [STAGES[i], STAGES[k]]).is_true()


func test_floor_grade_matches_shader_defaults() -> void:
	var c := Color(0.3, 0.5, 0.7)
	assert_bool(FloorGrade.apply(c, StageLook.new()).is_equal_approx(c)).is_true()  # 기본값이면 그대로


func test_enemy_rim_has_halo_and_strong_ghost_rim() -> void:
	var d: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var m := EnemyLook.material_for(d)
	assert_float(float(m.get_shader_parameter("halo_alpha"))).is_greater(0.0)
	assert_float(float(m.get_shader_parameter("ghost_rim_mix"))).is_less(1.0)


func test_swing_crescent_is_bigger_and_third_hit_biggest() -> void:
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	assert_float(feel.crescent_scale).is_greater(1.0)
	var s1 := ComboSteps.at(feel.crescent_step_scales, 1, 1.0)
	var s3 := ComboSteps.at(feel.crescent_step_scales, 3, 1.0)
	assert_float(s3).is_greater(s1)
	assert_float(feel.crescent_core_alpha).is_greater(0.0)


func test_arena_applies_stage_zoom_to_camera() -> void:
	var arena: Arena = auto_free(Arena.new())
	add_child(arena)
	arena.apply_theme(HANSAN)
	var cam: Camera2D = auto_free(Camera2D.new())
	arena.clamp_camera(cam)
	assert_vector(cam.zoom).is_equal_approx(Vector2.ONE * HANSAN.camera_zoom, Vector2.ONE * 0.001)
	assert_vector(cam.get_meta(&"base_zoom")).is_equal(cam.zoom)
	var plain := HANSAN.duplicate() as StageTheme
	plain.camera_zoom = 1.0
	arena.apply_theme(plain)
	arena.clamp_camera(cam)
	assert_vector(cam.zoom).is_equal(Vector2.ONE)


## 바닥 결 층: 회색 0.5 중심 (그림 밝기를 안 바꾸고 결만), 룩이 셰이더에 넘긴다.
func test_hansan_grain_is_mid_grey_and_used() -> void:
	var l: StageLook = HANSAN.look
	assert_object(l.detail_texture).is_not_null()
	assert_float(l.detail_strength).is_greater(0.0)
	var img := l.detail_texture.get_image()
	img.resize(64, 64)
	var sum := 0.0
	for y in 64:
		for x in 64:
			sum += img.get_pixel(x, y).r
	assert_float(sum / 4096.0).is_between(0.42, 0.58)


func test_arena_passes_grain_layer_to_shader() -> void:
	var arena: Arena = auto_free(Arena.new())
	add_child(arena)
	arena.apply_theme(HANSAN)
	var m := arena.map.material as ShaderMaterial
	assert_float(float(m.get_shader_parameter("detail_strength"))).is_equal_approx((HANSAN.look as StageLook).detail_strength, 0.001)
	assert_object(m.get_shader_parameter("detail_tex")).is_not_null()
	assert_vector(m.get_shader_parameter("map_px")).is_equal(arena.map.rect.size)
