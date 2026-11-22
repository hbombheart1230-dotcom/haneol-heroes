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
	var st: StageTheme = load("res://data/stages/manchuria_395.tres")
	assert_object(st.look).is_null()
	arena.apply_theme(st)
	assert_bool(arena.lights.visible).is_false()
	assert_int(arena.lights.pools.size()).is_equal(0)
	assert_bool(arena.lights.hero_glow.is_processing()).is_false()


func test_only_hansan_may_have_a_look() -> void:
	for id in ["manchuria_395", "gyeongbokgung_1433", "chochungdo"]:
		var st: StageTheme = load("res://data/stages/%s.tres" % id)
		assert_object(st.look).override_failure_message(id).is_null()


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
