extends GdUnitTestSuite
## 경복궁 엄폐가 판을 얼마나 바꾸나 (tests/hazard_runs.gd): 장치 없음 ↔ 엄폐, 같은 씨앗. 로그 [hazard-sim].
## 순신 원정은 날아가는 기술이 막히는 쪽(기본)과 안 막히는 쪽을 같이 재서 지나치게 어려워지지 않는지 본다.

const STAGE := "gyeongbokgung_1433"
const SEEDS := [11, 23, 37]


func after_test() -> void:
	BossSim.reset_globals()


func _three(hero: String, hz: bool, tweak: Callable = Callable(), tag: String = "") -> Array:
	var out := []
	for s in SEEDS:
		out.append(await HazardRuns.run(self, STAGE, hero, s, hz, true, tweak, tag))
	return out


func _line(name: String, rs: Array) -> String:
	return "%s %.1fs %.2f (막은 적 탄 %.1f, 막힌 영웅 기술 %.1f, 깨짐 %.1f)" % [name, HazardRuns.mean(rs, "time"),
		HazardRuns.mean(rs, "share"), HazardRuns.mean(rs, "cover_blocked_enemy"), HazardRuns.mean(rs, "cover_blocked_hero"),
		HazardRuns.mean(rs, "cover_broken")]


func test_sejong_home_with_cover() -> void:
	var off: Array = await _three("sejong", false)
	var on: Array = await _three("sejong", true)
	print("[hazard-sim] 세종 경복궁 평균: %s / %s" % [_line("없음", off), _line("엄폐", on)])
	for r: Dictionary in on:
		assert_bool(r["boss"]).is_true()
	assert_float(HazardRuns.mean(on, "time")).is_less_equal(HazardRuns.mean(off, "time") * 1.15)
	assert_float(HazardRuns.mean(on, "share")).is_less(0.6)


func test_sun_sin_expedition_is_not_too_hard() -> void:
	var off: Array = await _three("yi_sun_sin", false)
	var on: Array = await _three("yi_sun_sin", true)
	var free_shots: Array = await _three("yi_sun_sin", true,
		func(st: StageTheme) -> void: (st.hazards[0] as CoverData).block_hero_skills = false, "skills pass")
	print("[hazard-sim] 순신 경복궁 평균: %s / %s / %s" % [_line("없음", off), _line("엄폐", on), _line("기술은 넘음", free_shots)])
	for r: Dictionary in on:
		assert_bool(r["boss"]).is_true()
	assert_float(HazardRuns.mean(on, "time")).is_less_equal(HazardRuns.mean(off, "time") * 1.2)  # 원정은 조금 어려워도 된다
	assert_float(HazardRuns.mean(on, "share")).is_less(0.6)


func test_other_heroes_on_gyeongbok_with_cover() -> void:
	for hero in ["gwanggaeto", "shin_saimdang"]:
		var a: Dictionary = await HazardRuns.run(self, STAGE, hero, SEEDS[0], false)
		var b: Dictionary = await HazardRuns.run(self, STAGE, hero, SEEDS[0], true)
		assert_bool(b["boss"]).override_failure_message(hero).is_true()
		assert_float(b["share"]).override_failure_message(hero).is_less(0.6)
		assert_float(b["time"]).override_failure_message(hero).is_less_equal(a["time"] * 1.2)
