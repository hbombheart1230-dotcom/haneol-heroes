extends GdUnitTestSuite
## 사임당 기술 그림 ↔ 판정 (사용자: "모션·타이밍 다 좋다" → 크게 어긋난 것만): 매화 반격 고리가 기본 단계 화면 상한에 깎여
## 판정의 약 0.55배였고 조각이 1.3배로 튀어 들어왔다 → 고리 끝 = 반경 + 적 몸 (fit_exact). 판정 그대로.

func test_plum_ring_ends_at_the_reach() -> void:
	var d := (ResourceLoader.load("res://data/heroes/shin_saimdang.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData).kit.counter
	var cap := SkillGrowthData.get_default().cap_at(FxCoverage.TOP_LEVEL) * 720.0 * d.vfx_impact.art_fill * 0.5
	for lv in [0, 1, 3, 6]:
		d.vfx_level = lv
		var r: float = SkillGrowthData.get_default().scaled_def(d).get("radius")
		var fit: float = r + float(d.get("ring_edge_px"))
		var pl := FxCoverage.plan(d.vfx_impact, lv, fit, SkillStageFeel.new(), 720.0)
		var painted := float(pl["size"]) * d.vfx_impact.art_fill * 0.5
		assert_float(painted).override_failure_message("lv%d" % lv).is_equal_approx(minf(fit, cap), 0.5)
	assert_float(d.vfx_impact.piece_pop).is_equal(0.0)
	assert_bool(d.hero_over_fx).is_true()
