extends GdUnitTestSuite
## 해룡참 물결 고리는 처음 프레임부터 칼끝(판정 반경 + 적 몸)에 놓인다 (사용자 7ce32eb "원이 초기에 칼날 길이랑 안 맞는다").
## 예전: 기본 단계는 화면 상한에 깎여 판정의 0.86배, 조각은 1.3배 + 30px 밖에서 튀어 들어오고, 수명 동안 1.08배로 커졌다.

const HERO := "res://data/heroes/yi_sun_sin.tres"


func _tap() -> SkillDef:
	var h := ResourceLoader.load(HERO, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData
	return h.kit.tap


func test_ring_painted_edge_is_the_reach_at_every_level() -> void:
	var tap := _tap()
	var st := SkillStageFeel.new()
	for lv in [0, 1, 2, 3, 6, 9]:
		tap.vfx_level = lv
		var r: float = SkillGrowthData.get_default().scaled_def(tap).get("radius")
		var fit: float = r + float(tap.get("ring_edge_px"))
		for vw in [720.0]:  # 게임 화면 폭: 초반 단계 상한(0.36)에 깎이지 않는다 (맨 위 단계 상한 0.75만 안전판으로 남음)
			var pl := FxCoverage.plan(tap.vfx_impact, lv, fit, st, vw)
			var painted := float(pl["size"]) * tap.vfx_impact.art_fill * 0.5
			assert_float(painted).override_failure_message("level %d view %d: painted %.1f vs reach %.1f" % [lv, vw, painted, fit]) \
				.is_equal_approx(fit, 0.5)
			assert_float(float(pl["grow"])).is_equal(1.0)


func test_pieces_land_on_the_reach_from_the_first_frame() -> void:
	var v := _tap().vfx_impact
	assert_bool(v.fit_exact).is_true()
	assert_float(v.piece_pop).is_equal(0.0)
	assert_float(v.piece_push).is_equal(0.0)


func test_other_fitted_effects_keep_the_old_plan() -> void:
	var v := SkillVfxData.new()
	v.decal_size = 300.0
	v.decal_grow = 1.12
	v.art_fill = 0.9
	var pl := FxCoverage.plan(v, 0, 400.0, SkillStageFeel.new(), 720.0)
	assert_bool(bool(pl["exact"])).is_false()
	assert_float(float(pl["grow"])).is_greater(1.0)
