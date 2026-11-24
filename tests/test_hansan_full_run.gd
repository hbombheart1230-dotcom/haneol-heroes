extends GdUnitTestSuite
## 한산 한 판 전체 (보고용, HH_HANSAN=1일 때만): 네 영웅이 한산을 성장(tests/run_growth.gd)과 포격선(#114)과 함께 —
## 물결 → 3물결 중간 우두머리 무리 → 대장. 피하기·서툰 사람 × 씨앗 셋. 판 길이, 무리·대장 싸움 시간, 물결별 받은 피해, 포격 횟수.

const HINTS := {"yi_sun_sin": "순신", "gwanggaeto": "광개토", "sejong": "세종", "shin_saimdang": "사임당"}


func after_test() -> void:
	BossSim.reset_globals()


func test_hansan_full_run_report() -> void:
	if OS.get_environment("HH_HANSAN") != "1":
		assert_bool(true).is_true()
		return
	for hero in HINTS:
		for s in [11, 23, 37]:
			for miss in [0.0, 0.3]:
				var st := ResourceLoader.load("res://data/stages/hansan_1592.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageTheme
				st.hero_hint = HINTS[hero]
				var sim := RunSim.new(self)
				sim.use_hazards = true
				await sim.setup_run(st, s, [], true)
				var r := sim.run_full(miss)
				print(RunSim.growth_line("hansan %s seed %d %s" % [hero, s, "dodge" if miss == 0.0 else "sloppy"], r)
					+ " | trio %.1fs" % r["mid_time"])
				sim.free_all()
	assert_bool(true).is_true()
