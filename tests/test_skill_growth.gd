extends GdUnitTestSuite
## 강화 단계 성장 (SkillGrowthData): vfx_level → 단계, 판정과 그림이 같은 비율로, 발동 연출이 단계마다.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


func _g() -> SkillGrowthData:
	return SkillGrowthData.get_default()


func test_stage_thresholds() -> void:
	var g := _g()
	assert_int(g.stage_of(0)).is_equal(0)
	assert_int(g.stage_of(1)).is_equal(1)
	assert_int(g.stage_of(2)).is_equal(1)
	assert_int(g.stage_of(3)).is_equal(2)
	assert_int(g.stage_of(6)).is_equal(3)
	assert_int(g.stage_of(20)).is_equal(3)
	assert_float(g.size_at(0)).is_less(1.0)  # 기본은 작게
	assert_float(g.size_at(9)).is_greater(1.0)  # 최대는 크게
	assert_float(g.cap_at(9)).is_greater(g.cap_at(0))


## 열여섯 기술 모두 성장 단계를 쓰고, 판정 크기 속성이 하나 이상 있어 실제로 커진다.
func test_every_skill_grows_its_hit() -> void:
	var g := _g()
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		for d in [h.kit.tap, h.kit.dash, h.kit.charge, h.kit.counter]:
			assert_bool(SkillGrowthData.applies(d)).override_failure_message("%s %s" % [id, d.id]).is_true()
			var found := false
			for n in g.hit_props:
				if n in d and typeof(d.get(n)) == TYPE_FLOAT and float(d.get(n)) > 0.0:
					found = true
			assert_bool(found).override_failure_message("%s %s: no hit size property" % [id, d.id]).is_true()


func test_scaled_def_scales_hit_by_stage() -> void:
	var h: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var d := (h.kit.tap as SkillDef).duplicate() as SkillDef
	var r0 := float(d.get("radius"))
	d.vfx_level = 0
	var s0 := _g().scaled_def(d)
	assert_float(float(s0.get("radius"))).is_equal_approx(r0 * _g().size_at(0), 0.01)
	assert_object(s0).is_not_same(d)  # 사본 (원본 수치는 그대로)
	assert_float(float(d.get("radius"))).is_equal_approx(r0, 0.001)
	d.vfx_level = 9
	assert_float(float(_g().scaled_def(d).get("radius"))).is_equal_approx(r0 * _g().size_at(9), 0.01)


func test_skill_without_growth_is_untouched() -> void:
	var d := HaeryongSkill.new()
	d.growth = false
	assert_object(_g().scaled_def(d)).is_same(d)


## 그림 단계: 성장 효과면 크기·입자·겹·금빛 고리가 단계 값.
func test_vfx_follows_stage() -> void:
	var v := SkillVfxData.new()
	v.growth = true
	v.count = 10
	assert_float(v.size_mult(0)).is_equal_approx(_g().size_at(0), 0.001)
	assert_int(v.count_for(9)).is_greater(v.count_for(0))
	assert_int(v.layers_for(9)).is_greater(v.layers_for(0))
	assert_bool(v.ring_for(0)).is_false()
	assert_bool(v.ring_for(9)).is_true()


## 발동: 최대 단계에서 컷인, 기본에선 없음.
func test_cutin_at_top_stage() -> void:
	var d := HaeryongSkill.new()
	d.growth = true
	d.vfx_level = 0
	assert_bool(_g().on_cast(d)).is_false()
	d.vfx_level = 9
	assert_bool(_g().on_cast(d)).is_true()
