extends GdUnitTestSuite
## 한산 보스(왜군 지휘관)전 균형 (tests/boss_sim.gd): 순신이 가만히 있으면 지고, 예고를 보고 피하며 틈에 치면 이긴다.
## 같은 씨앗이면 실행·순서와 상관없이 같은 결과 (BossSim 머리말). 씨앗 셋으로 세 판씩 굴린다.
## 결과는 로그([boss-sim])에 남긴다: 걸린 시간, 받은 피해(종류별), 보스 타격 → 다음 예고 간격.

const BOSS_PATH := "res://data/enemies/waegun_commander.tres"
const SEEDS := [11, 23, 37]


func after_test() -> void:
	BossSim.reset_globals()


func _trials(name: String, bot: BossSim.Bot, contact: bool = true, miss: float = 0.0) -> Array:
	var out: Array = []
	for s in SEEDS:
		var sim := BossSim.new(self)
		await sim.setup(ResourceLoader.load(BOSS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData, s)
		sim.contact = contact
		sim.miss_rate = miss
		var r := sim.run(bot)
		print(BossSim.line("%s seed %d" % [name, s], r))
		sim.free_all()
		out.append(r)
	return out


func _count(rs: Array, key: String) -> int:
	return rs.filter(func(r: Dictionary) -> bool: return r[key]).size()


func test_standing_still_loses() -> void:
	var rs: Array = await _trials("idle", BossSim.Bot.IDLE)
	assert_int(_count(rs, "lost")).is_equal(SEEDS.size())


func test_tapping_without_dodging_loses() -> void:
	var rs: Array = await _trials("tap", BossSim.Bot.TAP)
	assert_int(_count(rs, "lost")).is_equal(SEEDS.size())


func test_dodging_and_punishing_wins() -> void:
	var rs: Array = await _trials("dodge", BossSim.Bot.DODGE)
	assert_int(_count(rs, "won")).is_equal(SEEDS.size())
	for r: Dictionary in rs:
		assert_float(r["time"]).is_between(35.0, 65.0)  # 목표 약 50초
		var w: Array = r["strikes"]  # 끊긴 예고(경직)는 다시 낼 수 있다: 실제로 친 차례만 본다
		for i in range(1, w.size()):
			assert_int(w[i]).override_failure_message("same attack twice: %s" % str(w)).is_not_equal(w[i - 1])


## 접촉 피해 없이 예고 공격만 (보고용: 공격 박자가 받는 피해).
func test_dodging_without_contact_report() -> void:
	var rs: Array = await _trials("dodge-nocontact", BossSim.Bot.DODGE, false)
	assert_int(rs.size()).is_equal(SEEDS.size())


## 서툰 사람 (예고 셋에 하나는 못 피함): 그래도 이기되 피해를 꽤 받는다 (보고용, 하데스 첫 보스 정도).
func test_sloppy_dodger_report() -> void:
	var rs: Array = await _trials("sloppy", BossSim.Bot.DODGE, true, 0.3)
	assert_int(rs.size()).is_equal(SEEDS.size())
