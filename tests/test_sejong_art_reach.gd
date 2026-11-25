extends GdUnitTestSuite
## 세종 기술 그림 ↔ 판정 (tools/shots/skill_reach_strip.gd, 판정은 그대로 두고 그림을 맞춤):
##  - 해시계 멈춤(반격): 기본 단계 화면 상한에 깎여 해시계 판이 판정의 약 0.55배, 조각이 1.22배 + 18px로 튀어 들어옴
##    → 판 끝 = 반경 + 적 몸 (fit_exact).
##  - 유성(대시): 떨어진 자리 그림이 반경에만 맞아 판정의 약 0.83배 → 반경 + 몸.
##  - 정음진(1번)은 +10~19%로 그대로, 성좌진(모으기) 선 굵기는 모으기 키우기 PR에서.

const HERO := "res://data/heroes/sejong.tres"


func test_dial_and_meteor_end_at_the_reach() -> void:
	var k := (ResourceLoader.load(HERO, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData).kit
	for d: SkillDef in [k.counter, k.dash]:
		var cap := SkillGrowthData.get_default().cap_at(FxCoverage.TOP_LEVEL) * 720.0 * d.vfx_impact.art_fill * 0.5
		for lv in [0, 1, 3, 6]:
			d.vfx_level = lv
			var r: float = SkillGrowthData.get_default().scaled_def(d).get("radius")
			var fit: float = r + float(d.get("ring_edge_px"))
			var pl := FxCoverage.plan(d.vfx_impact, lv, fit, SkillStageFeel.new(), 720.0)
			var painted := float(pl["size"]) * d.vfx_impact.art_fill * 0.5
			assert_float(painted).override_failure_message("%s lv%d" % [d.id, lv]).is_equal_approx(minf(fit, cap), 0.5)
			assert_float(float(pl["grow"])).is_equal(1.0)
	assert_float(k.counter.vfx_impact.piece_pop).is_equal(0.0)
