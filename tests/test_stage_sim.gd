extends GdUnitTestSuite
## 네 무대 물결 (tests/stage_sim.gd): 무대의 영웅이 피하며 치면 세 물결을 다 깨고 보스가 나온다 — 막힘 없이,
## 한산과 비슷한 시간에. 같은 씨앗이면 같은 결과. 결과는 로그([stage-sim])에 남긴다.

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]
## 씨앗 셋 (정예 변종·등장 자리가 달라진다): 길이는 세 판 평균으로 비교.
const SEEDS := [11, 23, 37]
var _runs := {}


func after_test() -> void:
	BossSim.reset_globals()


## contact = false면 접촉 피해를 세지 않는다 (봇은 둘러싸여도 제자리라 접촉이 지나치게 크다: 예고 공격만 비교).
func _run(id: String, s: int, contact: bool = true) -> Dictionary:
	var key := "%s/%d/%s" % [id, s, contact]
	if _runs.has(key):
		return _runs[key]
	var st := ResourceLoader.load("res://data/stages/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var sim := StageSim.new(self)
	sim.contact = contact
	await sim.setup_stage(st, s)
	var r := sim.run_waves()
	print(StageSim.stage_line("%s seed %d%s" % [id, s, "" if contact else " no-contact"], r))
	sim.free_all()
	_runs[key] = r
	return r


func test_every_stage_reaches_the_boss_without_stalling() -> void:
	for id in STAGES:
		var r: Dictionary = await _run(id, SEEDS[0])
		assert_bool(r["boss"]).override_failure_message("%s: %s" % [id, StageSim.stage_line(id, r)]).is_true()
		assert_int((r["cleared"] as Array).size()).override_failure_message(id).is_equal(3)
		assert_float(r["stall"]).override_failure_message(id).is_less(1.0)  # 숨 고르기 뒤 다음 물결이 바로
		assert_int(r["blocked"]).override_failure_message(id).is_equal(0)  # 장애물 속 등장 없음
		assert_int(r["spawned"]).override_failure_message(id).is_equal(50)  # 14 + 10 + 정예 + 24 + 보스
		assert_int(r["max_alive"]).override_failure_message(id).is_less_equal(10 + 1)  # 물결 상한 10 (+ 정예 한 마리)


## 무대 길이·받는 예고 공격 피해가 한산과 비슷하다 (물결만, 보스 전까지, 접촉 피해 빼고).
func test_stage_length_and_damage_match_hansan() -> void:
	var base: Array = await _mean("hansan_1592")
	for id in STAGES.slice(1):
		var m: Array = await _mean(id)
		var msg := "%s mean time %.1f (한산 %.1f), damage share %.2f (한산 %.2f)" % [id, m[0], base[0], m[1], base[1]]
		print("[stage-sim] " + msg)
		assert_float(m[0]).override_failure_message(msg).is_between(base[0] * 0.75, base[0] * 1.3)
		assert_float(m[1]).override_failure_message(msg).is_less(0.6)  # 피하며 치면 물결에서 죽지 않는다


## 세 씨앗 평균 [보스까지 초, 받은 피해 ÷ 영웅 체력]. 진 판은 시간 대신 한도(300초).
func _mean(id: String) -> Array:
	var hp := float((load(StageSim.hero_of(load("res://data/stages/%s.tres" % id))) as HeroData).max_hp)
	var t := 0.0
	var d := 0.0
	for s in SEEDS:
		var r: Dictionary = await _run(id, s, false)
		t += r["time"] if r["boss"] else 300.0
		d += r["damage"] / hp
	return [t / SEEDS.size(), d / SEEDS.size()]


func test_same_seed_same_run() -> void:
	var a: Dictionary = await _run("manchuria_395", 23)
	_runs.clear()
	var b: Dictionary = await _run("manchuria_395", 23)
	assert_str(StageSim.stage_line("x", a)).is_equal(StageSim.stage_line("x", b))
