extends GdUnitTestSuite
## 초충도 풀숲이 판을 얼마나 바꾸나 (tests/hazard_runs.gd): 장치 없음 ↔ 풀숲, 같은 씨앗. 로그 [hazard-sim].
## 봇은 풀숲을 일부러 쓰지 않는다 (가장 가까운 적에게 붙는다): 지나가다 숨고 기습하는 만큼만 바뀐다.

const STAGE := "chochungdo"
const SEEDS := [11, 23, 37]


func after_test() -> void:
	BossSim.reset_globals()


func _three(hero: String, hz: bool) -> Array:
	var out := []
	for s in SEEDS:
		out.append(await HazardRuns.run(self, STAGE, hero, s, hz))
	return out


func _line(name: String, rs: Array) -> String:
	return "%s %.1fs %.2f (숨음 %.1f, 놓친 겨냥 %.1f, 기습 %.1f, 기습 덤 %.0f)" % [name,
		HazardRuns.mean(rs, "time"), HazardRuns.mean(rs, "share"), HazardRuns.mean(rs, "grass_hides"),
		HazardRuns.mean(rs, "grass_lost_aims"), HazardRuns.mean(rs, "grass_ambushes"), HazardRuns.mean(rs, "grass_ambush_damage")]


func _check(hero: String, off: Array, on: Array, slack: float) -> void:
	print("[hazard-sim] %s 초충도 평균: %s / %s" % [hero, _line("없음", off), _line("풀숲", on)])
	for r: Dictionary in on:
		assert_bool(r["boss"]).override_failure_message(hero).is_true()
	assert_float(HazardRuns.mean(on, "time")).override_failure_message(hero).is_less_equal(HazardRuns.mean(off, "time") * slack)
	assert_float(HazardRuns.mean(on, "share")).override_failure_message(hero).is_less(0.6)


func test_saimdang_home_with_grass() -> void:
	_check("shin_saimdang", await _three("shin_saimdang", false), await _three("shin_saimdang", true), 1.1)


func test_sun_sin_expedition_with_grass() -> void:
	_check("yi_sun_sin", await _three("yi_sun_sin", false), await _three("yi_sun_sin", true), 1.15)


## 원정 영웅은 씨앗 셋 평균으로 본다: 씨앗 하나는 풀숲 겨냥이 크게 흔들린다 (광개토 씨앗 11: 109.8 → 133.2초, 셋 평균 118.7 → 122.4초).
func test_other_heroes_on_chochungdo_with_grass() -> void:
	for hero in ["gwanggaeto", "sejong"]:
		_check(hero, await _three(hero, false), await _three(hero, true), 1.2)
