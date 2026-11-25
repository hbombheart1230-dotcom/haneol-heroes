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


## 해일검기 (사용자 9e19cfb "맞는 범위도 그림에 맞추긴 해야지"): 판정 = 물결 그림의 눈에 보이는 몸통 캡슐 (Projectile.hit_body).
## 바로 놓음·다 모음 모두 캡슐 폭 = 그림 몸통 높이, 앞 끝 = 그림 앞 끝 근처. 뒤 날·잔상은 흐리게 (back_alpha).
func test_haeil_hit_is_the_visible_wave_body() -> void:
	var haeil := _kit().charge as HaeilSkill
	assert_bool(haeil.hit_body.has_area()).is_true()
	assert_float(haeil.crest_reach).is_equal(0.0)
	assert_float(haeil.back_alpha).is_less(1.0)
	for c in [0.0, 0.5, 1.0]:
		var p := Projectile.new()
		haeil._wave_configure(p, Vector2.RIGHT, c)
		p.rotation = 0.0
		p.scale = Vector2.ONE * p.size_scale
		var cap: Array = p.body_capsule()
		var half := float(cap[2]) * p.size_scale
		assert_float(half * 2.0).override_failure_message("charge %.1f" % c).is_equal_approx(haeil.aim_width(c), 0.5)
		var front := (-0.6 + haeil.hit_body.end.x) * p.art_size.x * p.size_scale  # 몸통 앞 끝 (그림 rect x = -0.6w .. 0.4w)
		assert_float(p.hit_reach(Vector2(front - 3.0 * p.size_scale, 0))).is_less(0.0)  # 몸통 앞 끝 바로 안은 맞음
		assert_float(p.hit_reach(Vector2(0, half * 0.95))).is_less(0.0)  # 몸통 옆 끝 안
		assert_float(p.hit_reach(Vector2(0, half * 1.3))).is_greater(0.0)  # 몸통 밖
		p.free()
