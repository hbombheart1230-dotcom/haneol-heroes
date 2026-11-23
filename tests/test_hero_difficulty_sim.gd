extends GdUnitTestSuite
## 영웅별 한 판 난이도 (tests/run_sim.gd, 결정적): 네 영웅 × 자기 무대 한 판 전체 (물결 → 중간 보스 → 보스).
## 받은 피해·판 길이·서툰 사람 승률이 영웅마다 비슷하고, 잡몹이 경직에 묶여 아무것도 못 하는 일이 없다.
## 보통 실행에서는 건너뛴다. HH_SLOW=1이면 씨앗 셋 × 피하기·서툰 사람 × 옛 경직 규칙·새 규칙 (보고 표, 오래 걸림).

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]
static var SLOW: bool = OS.get_environment("HH_SLOW") == "1"


func after_test() -> void:
	BossSim.reset_globals()
	_rules(true)


## 경직 규칙: true = 지금 (이어진 경직 상한 · 끊긴 다음 예고 지킴), false = 예전 (둘 다 끔, 전/후 비교용).
func _rules(on: bool) -> void:
	var r := Feedback.feel_data().reaction_data()
	var d := Feedback.feel_data().impact_data()
	var fresh := HitReactionData.new()
	r.stagger_chain_max = fresh.stagger_chain_max if on else 0.0
	r.stagger_guard = fresh.stagger_guard if on else 0.0
	r.crowd_stagger_falloff = fresh.crowd_stagger_falloff if on else 0.0
	d.interrupt_guard_next = on
	d.down_rearm = ImpactFeelData.new().down_rearm if on else 2.0
	RunSim.legacy_reach = not on  # #102 A: 무대 근접 잡몹 거리 130 → 170


func _run(id: String, s: int, miss: float) -> Dictionary:
	var st := ResourceLoader.load("res://data/stages/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
	var sim := RunSim.new(self)
	await sim.setup_run(st, s)
	var r := sim.run_full(miss)
	sim.free_all()
	return r


func test_report_table() -> void:
	if not SLOW:  # 보고용 (한 판 네 번 = 약 2분): 전체 스위트에서는 건너뛴다
		assert_bool(true).is_true()
		return
	var seeds := [11, 23, 37] if SLOW else [11]
	for on in ([false, true] if SLOW and OS.get_environment("HH_ONLY_NEW") != "1" else [true]):
		_rules(on)
		for id in STAGES:
			if OS.get_environment("HH_ONLY_STAGE") != "" and id != OS.get_environment("HH_ONLY_STAGE"):
				continue
			for s in seeds:
				var tag := "%s %s seed %d" % ["new" if on else "old", id, s]
				var r: Dictionary = await _run(id, s, 0.0)
				print(RunSim.run_line(tag + " dodge", r))
				if SLOW:
					print(RunSim.run_line(tag + " sloppy", await _run(id, s, 0.3)))
	assert_bool(true).is_true()
