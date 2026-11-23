extends GdUnitTestSuite
## 큰 기술 이펙트가 화면을 덮는 폭의 상한 (FxCoverage, SkillStageFeel "화면 덮기").

const W := 720.0


func _st() -> SkillStageFeel:
	return SkillStageFeel.new()


func _decal(pieces: int = 0) -> SkillVfxData:
	var d := SkillVfxData.new()
	d.decal = PlaceholderTexture2D.new()
	d.piece_count = pieces
	d.glow = 0.6
	d.glow_size = 1.4
	return d


func test_every_hero_skill_stays_under_cap_at_max_level_and_huge_radius() -> void:
	var st := _st()
	for id in ["yi_sun_sin", "sejong", "gwanggaeto", "shin_saimdang"]:
		var hero: HeroData = load("res://data/heroes/%s.tres" % id)
		for slot in ["tap", "dash", "charge", "counter"]:
			var s: SkillDef = hero.kit.get(slot)
			if s == null or s.vfx_impact == null or not s.vfx_impact.has_decal():
				continue
			for r in [0.0, 230.0, 900.0]:
				var pl := FxCoverage.plan(s.vfx_impact, 99, r, st, W)
				# 성장 단계 효과는 단계별 상한 (최대 단계는 SkillGrowthData.screen_cap 마지막 값)
				assert_float(float(pl["frac"])).is_less_equal(s.vfx_impact.screen_cap_for(99, st.screen_cap) + 0.001)


func test_cap_follows_camera_zoom() -> void:
	var st := _st()
	var d := _decal()
	var wide := FxCoverage.plan(d, 6, 400.0, st, W)
	var zoomed := FxCoverage.plan(d, 6, 400.0, st, W / 1.2)  # 영웅이 크게 보이게 줌하면 보이는 세계가 좁다
	assert_float(float(zoomed["size"])).is_less(float(wide["size"]))
	assert_float(float(zoomed["cover"])).is_less_equal(st.screen_cap * W / 1.2 + 0.01)


func test_fitted_art_barely_grows() -> void:
	var st := _st()
	var d := _decal()
	assert_float(FxCoverage.grow_of(d, true, st)).is_equal(st.fit_grow)
	assert_float(FxCoverage.grow_of(d, false, st)).is_equal(d.decal_grow)


func test_small_effect_untouched() -> void:
	var st := _st()
	var d := _decal()
	d.glow_size = 0.9
	var pl := FxCoverage.plan(d, 0, 60.0, st, W)  # 판정 지름 120px: 화면의 일부
	assert_float(float(pl["size"])).is_equal_approx(d.fitted_size(60.0), 0.01)
	assert_bool(pl["big"]).is_false()
	assert_float(float(pl["time"])).is_equal(1.0)
	assert_float(float(pl["light"])).is_equal(1.0)
	assert_float(float(pl["core"])).is_equal(1.0)


func test_big_effect_softer_shorter_and_hollow() -> void:
	var st := _st()
	var pl := FxCoverage.plan(_decal(8), 6, 300.0, st, W)
	assert_bool(pl["big"]).is_true()
	assert_float(float(pl["time"])).is_equal(st.big_time)
	assert_float(float(pl["light"])).is_equal(st.big_light)
	assert_float(float(pl["core"])).is_equal(st.big_core)
	assert_float(st.big_time).is_less(1.0)
	assert_float(st.big_light).is_less(1.0)
	assert_float(st.big_core).is_less(1.0)


func test_glow_and_ground_capped_too() -> void:
	var st := _st()
	var d := _decal(8)
	d.ground_size = 900.0
	var pl := FxCoverage.plan(d, 6, 300.0, st, W)
	assert_float(float(pl["size"]) * float(pl["glow_k"])).is_less_equal(st.screen_cap * W + 0.01)
	assert_float(float(pl["size"]) * float(pl["flash_k"])).is_less_equal(st.screen_cap * W + 0.01)
	assert_float(float(pl["cover"])).is_less_equal(st.screen_cap * W + 0.01)


func test_burst_applies_plan_to_pieces() -> void:
	var v: VfxDecals = auto_free(VfxDecals.new())
	var d := _decal(8)
	d.decal_time = 1.0
	v.burst(d, Vector2.ZERO, Vector2.RIGHT, 6, 300.0)
	var set: Dictionary = v.pieces._sets[0]
	var st := v.pieces.stage
	assert_float(float(set["size"]) * float(set["grow"])).is_less_equal(st.screen_cap * W + 0.01)
	assert_float(float(set["core"])).is_equal(st.big_core)
	assert_float(float(set["flash"])).is_equal_approx(d.piece_flash * st.big_light, 0.001)
	assert_float(float(set["glow"])).is_equal_approx(d.glow_for(6) * st.big_light, 0.001)


func test_burst_shortens_big_plain_decal() -> void:
	var v: VfxDecals = auto_free(VfxDecals.new())
	var d := _decal()
	d.decal_time = 1.0
	d.decal_size = 600.0
	v.burst(d, Vector2.ZERO, Vector2.ZERO, 6)
	var it: Dictionary = v._items[0]
	assert_float(float(it["life"])).is_equal_approx(v.pieces.stage.big_time, 0.001)


func test_level_size_capped() -> void:
	var d := SkillVfxData.new()
	d.level_size = 0.2
	d.max_size_mult = 1.4
	assert_float(d.size_mult(2)).is_equal_approx(1.4, 0.001)
	assert_float(d.size_mult(6)).is_equal_approx(1.4, 0.001)
	assert_float(d.size_mult(1)).is_equal_approx(1.2, 0.001)


func test_cap_off_keeps_old_size() -> void:
	var st := _st()
	st.screen_cap = 0.0
	var d := _decal()
	assert_float(FxCoverage.capped(1000.0, 1.35, st, W)).is_equal(1000.0)
