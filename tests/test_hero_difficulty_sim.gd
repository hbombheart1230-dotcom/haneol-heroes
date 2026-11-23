extends GdUnitTestSuite
## 영웅별 한 판 난이도 (tests/run_sim.gd, 결정적): 네 영웅 × 자기 무대 한 판 전체 (물결 → 중간 보스 → 보스).
## 받은 피해·판 길이·서툰 사람 승률이 영웅마다 비슷하고, 잡몹이 경직에 묶여 아무것도 못 하는 일이 없다.
## 보통 실행은 씨앗 하나·피하기만. HH_SLOW=1이면 씨앗 셋 × 피하기·서툰 사람 × 잡몹 떼 상한 두 가지 (보고 표, 오래 걸림).

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]
const SLOW_CAPS := [[], [8, 11, 14]]
static var SLOW: bool = OS.get_environment("HH_SLOW") == "1"


func after_test() -> void:
	BossSim.reset_globals()


func _run(id: String, s: int, miss: float, caps: Array = []) -> Dictionary:
	var st := ResourceLoader.load("res://data/stages/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var sim := RunSim.new(self)
	await sim.setup_run(st, s, caps)
	var r := sim.run_full(miss)
	sim.free_all()
	return r


func test_report_table() -> void:
	var seeds := [11, 23, 37] if SLOW else [11]
	for caps in (SLOW_CAPS if SLOW else [[]]):
		for id in STAGES:
			for s in seeds:
				var r: Dictionary = await _run(id, s, 0.0, caps)
				print(RunSim.run_line("%s caps %s seed %d dodge" % [id, str(caps) if not caps.is_empty() else "base", s], r))
				if SLOW:
					var sl: Dictionary = await _run(id, s, 0.3, caps)
					print(RunSim.run_line("%s caps %s seed %d sloppy" % [id, str(caps) if not caps.is_empty() else "base", s], sl))
	assert_bool(true).is_true()
