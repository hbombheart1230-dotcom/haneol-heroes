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


## 물결 흐름 (막힘·장애물 속 등장·화면 상한·적 수)은 접촉 피해 없이 세 씨앗 모두에서 본다 (봇 생존과 따로).
func test_every_stage_reaches_the_boss_without_stalling() -> void:
	for id in STAGES:
		for s in SEEDS:
			var r: Dictionary = await _run(id, s, false)
			var line := StageSim.stage_line("%s seed %d no-contact" % [id, s], r)
			assert_bool(r["boss"]).override_failure_message(line).is_true()
			assert_int((r["cleared"] as Array).size()).override_failure_message(line).is_equal(4)  # 물결 넷 (그 뒤 보스)
			assert_float(r["stall"]).override_failure_message(line).is_less(1.0)  # 숨 고르기 뒤 다음 물결이 바로
			assert_int(r["blocked"]).override_failure_message(line).is_equal(0)  # 장애물 속 등장 없음
			var st: StageTheme = load("res://data/stages/%s.tres" % id)
			var planned := 2  # 정예(중간 보스) + 보스
			for w: WaveData in st.waves.waves:
				planned += w.enemies.size()
			assert_int(r["spawned"]).override_failure_message(line).is_greater_equal(planned)  # 물결 적 다 + 정예 + 보스 (중간 보스 소환은 더)
			assert_int(r["max_alive"]).override_failure_message(line).is_less_equal(st.waves.max_alive + st.waves.alive_cap_add + 1)  # 화면 상한 (밀도 더하기 + 정예 한 마리)


## 접촉 피해까지 켜면 봇(둘러싸여도 제자리)이 씨앗마다 크게 갈린다 (한산: 같은 코드에서 피해 0 ↔ 접촉 100이 씨앗만 바꿔 뒤집힘):
## 한 씨앗으로 정하지 않고 세 씨앗 중 둘 이상에서 보스까지 산다.
func test_hero_survives_contact_on_most_seeds() -> void:
	for id in STAGES:
		var alive := 0
		var lines: PackedStringArray = []
		for s in SEEDS:
			var r: Dictionary = await _run(id, s)
			alive += int(r["boss"])
			lines.append(StageSim.stage_line("%s seed %d" % [id, s], r))
		assert_int(alive).override_failure_message("
".join(lines)).is_greater_equal(SEEDS.size() - 1)


## 무대 길이·받는 예고 공격 피해가 한산과 비슷하다 (물결만, 보스 전까지, 접촉 피해 빼고).
func test_stage_length_and_damage_match_hansan() -> void:
	var base: Array = await _mean("hansan_1592")
	for id in STAGES.slice(1):
		var m: Array = await _mean(id)
		var msg := "%s mean time %.1f (한산 %.1f), damage share %.2f (한산 %.2f)" % [id, m[0], base[0], m[1], base[1]]
		print("[stage-sim] " + msg)
		assert_float(m[0]).override_failure_message(msg).is_between(base[0] * 0.65, base[0] * 1.35)  # 영웅 기술 차이 (세종 글자 고리·사임당이 떼를 더 빨리 쓴다)
		assert_float(m[1]).override_failure_message(msg).is_less(0.6)  # 피하며 치면 물결에서 죽지 않는다


## 세 씨앗 평균 [보스까지 초 (정예·중간 보스와 싸운 시간 빼고: 한산만 중간 보스라 잡몹 물결 길이를 비교), 받은 피해 ÷ 영웅 체력].
## 진 판은 시간 대신 한도(300초).
func _mean(id: String) -> Array:
	var hp := float((load(StageSim.hero_of(load("res://data/stages/%s.tres" % id))) as HeroData).max_hp)
	var t := 0.0
	var d := 0.0
	for s in SEEDS:
		var r: Dictionary = await _run(id, s, false)
		t += r["time"] - maxf(r["mid_time"], 0.0) if r["boss"] else 300.0
		d += r["damage"] / hp
	return [t / SEEDS.size(), d / SEEDS.size()]


func test_same_seed_same_run() -> void:
	var a: Dictionary = await _run("manchuria_395", 23)
	_runs.clear()
	var b: Dictionary = await _run("manchuria_395", 23)
	assert_str(StageSim.stage_line("x", a)).is_equal(StageSim.stage_line("x", b))


## 한산 순신 판도 같은 씨앗 = 같은 판: 멈춤(GameTime)·칼 박힘(BladeBite)이 실제 시각을 쓰면 기계 속도에 따라 갈렸다
## (같은 실행 안에서 씨앗 11이 이김·짐·이김). 시뮬레이션은 GameTime.clock에 판 시각을 넣는다.
func test_same_seed_same_run_with_hit_stops() -> void:
	var a: Dictionary = await _run("hansan_1592", 11)
	_runs.clear()
	var b: Dictionary = await _run("hansan_1592", 11)
	assert_str(StageSim.stage_line("x", a)).is_equal(StageSim.stage_line("x", b))
	GameTime.clock = func() -> int: return 1000
	GameTime.stop(get_tree(), 0.5)
	assert_bool(GameTime.is_stopped()).is_true()
	GameTime.clock = func() -> int: return 1600
	assert_bool(GameTime.is_stopped()).is_false()  # 실제 시각이 아니라 넣은 시각으로 풀린다
	GameTime.clock = Callable()
	GameTime.reset()
