extends GdUnitTestSuite
## 경복궁 엄폐가 판을 얼마나 바꾸나 (tests/hazard_runs.gd): 장치 없음 ↔ 엄폐, 같은 씨앗. 로그 [hazard-sim].
## 순신 원정은 날아가는 기술이 막히는 쪽(기본)과 안 막히는 쪽을 같이 재서 지나치게 어려워지지 않는지 본다.
##
## 조건을 둘로 나눈다 (2026-11-26):
## - 엄폐 효과(기준 피해 몫 0.6 미만·시간)는 원거리 대형을 뺀 판에서 잰다: 흩어진 궁수·정예·우두머리 탄 = 가림막이 막으라고 둔 것.
## - 여진 궁수 둥근 진(gyeongbok_jurchen_ring)은 영웅을 가운데 두고 둘러싼다 (사용자 "영웅을 두고 동그랗게 서는게 간진데").
##   사방에서 쏘므로 숨는 것이 아니라 뚫고 나가거나 한 번에 쓸어야 하는 상황으로 설계상 인정한다 — 가림막 기준으로 재면
##   대형 자체가 기준을 깨므로(광개토 엄폐 0.85~0.90) 대형이 있는 판은 기록과 느슨한 상한(우두머리까지 감·죽지 않음)만 둔다.
##   일제 사격 공정성(한 번에 최대 2발·무적)은 VolleyFeelData.max_hero_hits, 빠져나갈 틈은 test_formation_3stages.

const STAGE := "gyeongbokgung_1433"
const SEEDS := [11, 23, 37]


func after_test() -> void:
	BossSim.reset_globals()


## 원거리 대형을 모든 물결에서 뺀다 (가림막이 막는 탄만 남긴다).
static func no_formations(st: StageTheme) -> void:
	for w: WaveData in st.waves.waves:
		w.formations = []
		w.formation_after = PackedInt32Array()


func _three(hero: String, hz: bool, tweak: Callable = Callable(), tag: String = "", plain := true) -> Array:
	var t := tweak
	if plain:
		t = func(st: StageTheme) -> void:
			no_formations(st)
			if tweak.is_valid():
				tweak.call(st)
	var out := []
	for s in SEEDS:
		out.append(await HazardRuns.run(self, STAGE, hero, s, hz, true, t, tag if not plain else ("no formation " + tag).strip_edges()))
	return out


func _line(name: String, rs: Array) -> String:
	return "%s %.1fs %.2f (막은 적 탄 %.1f, 막힌 영웅 기술 %.1f, 깨짐 %.1f)" % [name, HazardRuns.mean(rs, "time"),
		HazardRuns.mean(rs, "share"), HazardRuns.mean(rs, "cover_blocked_enemy"), HazardRuns.mean(rs, "cover_blocked_hero"),
		HazardRuns.mean(rs, "cover_broken")]


## 대형이 있는 실제 판 (엄폐 켬): 기록 + 느슨한 상한 — 세 씨앗 중 둘 이상 우두머리, 평균으로 죽지 않음.
func _with_ring(hero: String, label: String) -> void:
	var rs: Array = await _three(hero, true, Callable(), "with ring", false)
	print("[hazard-sim] %s 경복궁 둥근 진 포함 (기록): %s" % [label, _line("엄폐", rs)])
	assert_int(rs.filter(func(r: Dictionary) -> bool: return r["boss"]).size()).override_failure_message(label).is_greater_equal(2)
	assert_float(HazardRuns.mean(rs, "share")).override_failure_message(label).is_less(1.0)


func test_sejong_home_with_cover() -> void:
	var off: Array = await _three("sejong", false)
	var on: Array = await _three("sejong", true)
	print("[hazard-sim] 세종 경복궁 평균 (대형 뺌): %s / %s" % [_line("없음", off), _line("엄폐", on)])
	for r: Dictionary in on:
		assert_bool(r["boss"]).is_true()
	assert_float(HazardRuns.mean(on, "time")).is_less_equal(HazardRuns.mean(off, "time") * 1.15)
	assert_float(HazardRuns.mean(on, "share")).is_less(0.6)
	await _with_ring("sejong", "세종")


func test_sun_sin_expedition_is_not_too_hard() -> void:
	var off: Array = await _three("yi_sun_sin", false)
	var on: Array = await _three("yi_sun_sin", true)
	var free_shots: Array = await _three("yi_sun_sin", true,
		func(st: StageTheme) -> void: (st.hazards[0] as CoverData).block_hero_skills = false, "skills pass")
	print("[hazard-sim] 순신 경복궁 평균 (대형 뺌): %s / %s / %s" % [_line("없음", off), _line("엄폐", on), _line("기술은 넘음", free_shots)])
	for r: Dictionary in on:
		assert_bool(r["boss"]).is_true()
	assert_float(HazardRuns.mean(on, "time")).is_less_equal(HazardRuns.mean(off, "time") * 1.2)  # 원정은 조금 어려워도 된다
	assert_float(HazardRuns.mean(on, "share")).is_less(0.6)
	await _with_ring("yi_sun_sin", "순신")


## 원정 영웅은 씨앗 셋 평균으로 본다 (씨앗 하나는 크게 흔들린다: 광개토 씨앗 11은 엄폐 없이 74초에 짐, 엄폐로는 117초에 우두머리).
func test_other_heroes_on_gyeongbok_with_cover() -> void:
	for hero in ["gwanggaeto", "shin_saimdang"]:
		var off: Array = await _three(hero, false)
		var on: Array = await _three(hero, true)
		print("[hazard-sim] %s 경복궁 평균 (대형 뺌): %s / %s" % [hero, _line("없음", off), _line("엄폐", on)])
		assert_int(on.filter(func(r: Dictionary) -> bool: return r["boss"]).size()).override_failure_message(hero).is_greater_equal(2)  # 세 씨앗 중 둘 이상 (성장 없는 봇)
		assert_float(HazardRuns.mean(on, "share")).override_failure_message(hero).is_less(0.6)
		assert_float(HazardRuns.mean(on, "time")).override_failure_message(hero).is_less_equal(HazardRuns.mean(off, "time") * 1.2)
		await _with_ring(hero, hero)
