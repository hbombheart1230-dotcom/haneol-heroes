extends GdUnitTestSuite
## 광개토 기술 그림 ↔ 판정 (tools/shots/skill_reach_strip.gd, 판정은 그대로 두고 그림을 맞춤):
##  - 지진(1번)·정복자의 일격(반격): 고리를 반경에만 맞추고 조각이 1.35~1.4배 + 34~44px 밖에서 튀어 들어옴,
##    기본 단계 화면 상한, 금빛 고리 눌린 타원 → 고리 끝 = 반경 + 적 몸 (해룡참과 같은 fit_exact).
##  - 낙뢰(모으기): 불똥 그림이 판정과 상관없는 크기 (판정의 1.4~1.6배) → splash_radius + 몸에 맞춤.
##  - 벼락길(대시): 띠 폭이 판정의 약 0.74배 → 성장 1배에서 폭 + 몸 둘.
##  - 네 기술 모두 시전 동안 영웅을 그림 위에 (hero_over_fx): 지진 갈라짐이 영웅을 몇 프레임 덮었다.

const HERO := "res://data/heroes/gwanggaeto.tres"


func _kit() -> SkillKit:
	return (ResourceLoader.load(HERO, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData).kit


func _painted(d: SkillDef, lv: int, fit: float) -> float:
	var pl := FxCoverage.plan(d.vfx_impact, lv, fit, SkillStageFeel.new(), 720.0)
	assert_float(float(pl["grow"])).is_equal(1.0)
	return float(pl["size"]) * d.vfx_impact.art_fill * 0.5


func test_ring_skills_end_at_the_reach() -> void:
	var cap := SkillGrowthData.get_default().cap_at(FxCoverage.TOP_LEVEL) * 720.0
	for d in [_kit().tap, _kit().counter]:
		for lv in [0, 1, 3, 6]:
			d.vfx_level = lv
			var r: float = SkillGrowthData.get_default().scaled_def(d).get("radius")
			var fit: float = r + float(d.get("ring_edge_px"))
			var want := minf(fit, cap * d.vfx_impact.art_fill * 0.5)
			assert_float(_painted(d, lv, fit)).override_failure_message("%s lv%d" % [d.id, lv]).is_equal_approx(want, 0.5)
		assert_float(d.vfx_impact.piece_pop).is_equal(0.0)
		assert_float(d.vfx_impact.piece_push).is_equal(0.0)


func test_lightning_splash_art_is_the_splash_reach() -> void:
	var d := _kit().charge
	for lv in [0, 3, 6]:
		d.vfx_level = lv
		var r: float = SkillGrowthData.get_default().scaled_def(d).get("splash_radius")
		var fit: float = r + float(d.get("splash_edge_px"))
		assert_float(_painted(d, lv, fit)).override_failure_message("lv%d" % lv).is_equal_approx(fit, 0.5)


func test_trail_band_width_is_the_hit_width() -> void:
	var d := _kit().dash
	assert_float(d.vfx_impact.strip_width).is_equal_approx(float(d.get("width")) + 40.0, 0.5)


func test_skills_draw_the_hero_over_their_art() -> void:
	var k := _kit()
	for d in [k.tap, k.dash, k.charge, k.counter]:
		assert_bool((d as SkillDef).hero_over_fx).override_failure_message(String(d.id)).is_true()
