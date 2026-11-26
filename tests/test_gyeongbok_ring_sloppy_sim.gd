extends GdUnitTestSuite
## 경복궁 여진 궁수 둘레 원 × 서툰 사람 (느린 묶음, HH_SLOW=1에서만): 한 판 전체(RunSim, 물결 → 중간 보스 → 보스),
## 판 안 성장(레벨·패·기술 성장) 넣고, miss_rate 0.3, 씨앗 11·23·37. 실제 무대 그대로 (대형 1·2·3번, 장전 3.4).
## 기준 (사용자 "아파도 된다", 기준은 하나): 서툰 사람이 세 판 중 둘은 이긴다 — 세종·순신·사임당.
## 광개토는 원이 없어도 같은 값이라 대형 탓이 아니어서 기록만 (#259 측정: 원 없음 3/3, 장전 2.4 3/3, 3.4 3/3).
## #259 측정 (원 없음 / 장전 2.4 / 3.4): 세종 2/3·0/3·2/3, 순신 2/3·3/3·3/3, 사임당 3/3·3/3·3/3.
## 보통 실행에서는 건너뛴다 (영웅마다 시험 하나 = 세 판 ≈ 1분, 모두 ≈ 4분).

const STAGE := "gyeongbokgung_1433"
const SEEDS := [11, 23, 37]
const MISS := 0.3
static var SLOW: bool = OS.get_environment("HH_SLOW") == "1"


func after_test() -> void:
	BossSim.reset_globals()


func _run(hint: String, s: int) -> Dictionary:
	var st := ResourceLoader.load("res://data/stages/%s.tres" % STAGE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	st.hero_hint = hint
	var sim := RunSim.new(self)
	await sim.setup_run(st, s, [], true)
	var r := sim.run_full(MISS)
	sim.free_all()
	return r


## 영웅마다 따로 (한 함수 = 세 판, gdUnit 시험 하나 300초 한도 안).
func _hero(hint: String, must_win: bool) -> void:
	if not SLOW:
		assert_bool(true).is_true()
		return
	var won := 0
	for s in SEEDS:
		var r: Dictionary = await _run(hint, s)
		won += 1 if r["won"] else 0
		print(RunSim.growth_line("[ring-sloppy] %s seed %d" % [hint, s], r))
	print("[ring-sloppy] %s 경복궁 서툰 사람 %d/3" % [hint, won])
	if must_win:
		assert_int(won).override_failure_message("%s 서툰 사람 %d/3" % [hint, won]).is_greater_equal(2)
	else:
		assert_bool(true).is_true()


func test_sejong_sloppy_wins_two_of_three() -> void:
	await _hero("세종", true)


func test_sun_sin_sloppy_wins_two_of_three() -> void:
	await _hero("순신", true)


func test_saimdang_sloppy_wins_two_of_three() -> void:
	await _hero("사임당", true)


func test_gwanggaeto_sloppy_recorded() -> void:
	await _hero("광개토", false)
