extends GdUnitTestSuite
## 순신 기술 그림 ↔ 판정 (tools/shots/skill_reach_strip.gd로 잰 것, 판정은 그대로 두고 그림을 맞춤):
##  - 강화 반격: 기본 단계 화면 상한에 깎여 고리가 칼끝의 약 0.6배, 조각이 1.45배 + 40px 밖에서 튀어 들어옴,
##    X자 칼자국 0.83배 → 고리 끝·칼자국 끝 = 반경 + 적 몸 (해룡참과 같은 fit_exact).
##  - 파도격: 세 타가 0·0.07·0.14초에 길 전체를 치는데 물결 띠는 0.18초에 걸쳐 펼쳐짐 → 둘째 타 전에 끝까지.
##  - 해룡참·파도격·해일검기·반격: 시전 동작 동안 영웅을 기술 그림 위에 (#183 hero_over_fx).

const HERO := "res://data/heroes/yi_sun_sin.tres"


func _kit() -> SkillKit:
	return (ResourceLoader.load(HERO, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData).kit


func test_counter_ring_ends_at_the_blade_reach_at_every_level() -> void:
	var counter := _kit().counter
	for lv in [0, 1, 3, 6, 9]:
		counter.vfx_level = lv
		var r: float = SkillGrowthData.get_default().scaled_def(counter).get("radius")
		var fit: float = r + float(counter.get("ring_edge_px"))
		var pl := FxCoverage.plan(counter.vfx_impact, lv, fit, SkillStageFeel.new(), 720.0)
		var painted := float(pl["size"]) * counter.vfx_impact.art_fill * 0.5
		# 맨 위 단계 화면 상한(폭의 0.75)은 안전판으로 남는다: 반격은 3단계부터 판정이 그보다 커서 상한까지만
		var cap := SkillGrowthData.get_default().cap_at(FxCoverage.TOP_LEVEL) * 720.0 * counter.vfx_impact.art_fill * 0.5
		var msg := "level %d painted %.0f reach %.0f" % [lv, painted, fit]
		assert_float(painted).override_failure_message(msg).is_equal_approx(minf(fit, cap), 0.5)
		assert_float(float(pl["grow"])).is_equal(1.0)
	assert_float(counter.vfx_impact.piece_pop).is_equal(0.0)
	assert_float(counter.vfx_impact.piece_push).is_equal(0.0)


func test_pado_band_reaches_the_end_before_the_second_hit() -> void:
	var pado := _kit().dash
	assert_float(pado.vfx_impact.strip_reveal).is_less_equal(float(pado.get("hit_interval")) + 0.001)


func test_big_skills_draw_the_hero_over_their_art() -> void:
	var k := _kit()
	for d in [k.tap, k.dash, k.charge, k.counter]:
		assert_bool((d as SkillDef).hero_over_fx).override_failure_message(String(d.id)).is_true()


## 해일검기 (사용자 결정 (b)): 앞 물마루의 앞 끝·옆 끝 = 판정 원(12px × 크기) + 적 몸 22px, 뒤 큰 물결은 흐리게.
func test_haeil_crest_matches_the_hit_circle() -> void:
	var haeil := _kit().charge as HaeilSkill
	assert_float(haeil.back_alpha).is_less(1.0)  # 뒤 물결은 흐리게 (사용자 결정 0.6)
	for c in [0.0, 0.5, 1.0]:
		var p := Projectile.new()
		haeil._wave_configure(p, Vector2.RIGHT, c)
		var hit := Projectile.HIT_R * p.size_scale + 22.0
		assert_float(p.crest_half() * p.size_scale).override_failure_message("charge %.1f" % c).is_equal_approx(hit, 0.5)
		p.free()
