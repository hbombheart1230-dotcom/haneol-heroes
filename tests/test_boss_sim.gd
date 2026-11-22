extends GdUnitTestSuite
## 한산 보스(왜군 지휘관)전 균형 (tests/boss_sim.gd): 순신이 가만히 있으면 지고, 예고를 보고 피하며 틈에 치면 이긴다.
## 적 움직임이 인스턴스 번호를 씨앗으로 써서 판마다 조금 다르다 → 씨앗 셋으로 세 판씩 굴린다.
## 결과는 로그([boss-sim])에 남긴다: 걸린 시간, 받은 피해(종류별), 보스 타격 → 다음 예고 간격.

const BOSS := preload("res://data/enemies/waegun_commander.tres")
const SEEDS := [11, 23, 37]


func after_test() -> void:
	GameTime.reset()


func _trials(name: String, bot: BossSim.Bot, contact: bool = true, miss: float = 0.0) -> Array:
	var out: Array = []
	for s in SEEDS:
		seed(s)
		var sim := BossSim.new(self)
		sim.setup(BOSS)
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
	var rs := _trials("idle", BossSim.Bot.IDLE)
	assert_int(_count(rs, "lost")).is_equal(SEEDS.size())


func test_tapping_without_dodging_loses() -> void:
	var rs := _trials("tap", BossSim.Bot.TAP)
	assert_int(_count(rs, "lost")).is_equal(SEEDS.size())


func test_dodging_and_punishing_wins() -> void:
	var rs := _trials("dodge", BossSim.Bot.DODGE)
	assert_int(_count(rs, "won")).is_equal(SEEDS.size())


## 접촉 피해 없이 예고 공격만 (보고용: 공격 박자가 받는 피해).
func test_dodging_without_contact_report() -> void:
	var rs := _trials("dodge-nocontact", BossSim.Bot.DODGE, false)
	assert_int(rs.size()).is_equal(SEEDS.size())


## 서툰 사람 (예고 셋에 하나는 못 피함): 그래도 이기되 피해를 꽤 받는다 (보고용, 하데스 첫 보스 정도).
func test_sloppy_dodger_report() -> void:
	var rs := _trials("sloppy", BossSim.Bot.DODGE, true, 0.3)
	assert_int(rs.size()).is_equal(SEEDS.size())
