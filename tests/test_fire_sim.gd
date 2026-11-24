extends GdUnitTestSuite
## 만주 들불이 판을 얼마나 바꾸나 (tests/hazard_runs.gd): 장치 없음 ↔ 들불, 같은 씨앗. 로그 [hazard-sim].
## 봇은 불을 피하지 않는다 (불 위에 서 있어도 싸운다 = 영웅이 가장 많이 타는 쪽).

const STAGE := "manchuria_395"
const SEEDS := [11, 23, 37]


func after_test() -> void:
	BossSim.reset_globals()


func _three(hero: String, hz: bool) -> Array:
	var out := []
	for s in SEEDS:
		out.append(await HazardRuns.run(self, STAGE, hero, s, hz))
	return out


func _line(name: String, rs: Array) -> String:
	return "%s %.1fs %.2f (붙은 칸 %.0f, 꺼진 칸 %.0f, 불씨 %.1f, 적 탄 틱 %.0f, 영웅 탄 틱 %.1f)" % [name,
		HazardRuns.mean(rs, "time"), HazardRuns.mean(rs, "share"), HazardRuns.mean(rs, "fire_ignited"),
		HazardRuns.mean(rs, "fire_doused"), HazardRuns.mean(rs, "fire_embers"), HazardRuns.mean(rs, "fire_enemy_ticks"),
		HazardRuns.mean(rs, "fire_hero_ticks")]


func _check(hero: String, off: Array, on: Array, slack: float) -> void:
	print("[hazard-sim] %s 만주 평균: %s / %s" % [hero, _line("없음", off), _line("들불", on)])
	for r: Dictionary in on:
		assert_bool(r["boss"]).override_failure_message(hero).is_true()
	assert_float(HazardRuns.mean(on, "time")).override_failure_message(hero).is_less_equal(HazardRuns.mean(off, "time") * slack)
	assert_float(HazardRuns.mean(on, "share")).override_failure_message(hero).is_less(0.6)


func test_gwanggaeto_home_with_fire() -> void:
	_check("gwanggaeto", await _three("gwanggaeto", false), await _three("gwanggaeto", true), 1.1)


func test_sun_sin_expedition_with_fire() -> void:
	_check("yi_sun_sin", await _three("yi_sun_sin", false), await _three("yi_sun_sin", true), 1.2)


func test_other_heroes_on_manchuria_with_fire() -> void:
	for hero in ["sejong", "shin_saimdang"]:
		var a: Dictionary = await HazardRuns.run(self, STAGE, hero, SEEDS[0], false)
		var b: Dictionary = await HazardRuns.run(self, STAGE, hero, SEEDS[0], true)
		assert_bool(b["boss"]).override_failure_message(hero).is_true()
		assert_float(b["share"]).override_failure_message(hero).is_less(0.6)
		assert_float(b["time"]).override_failure_message(hero).is_less_equal(a["time"] * 1.2)
