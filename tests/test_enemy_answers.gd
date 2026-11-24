extends GdUnitTestSuite
## 정답 표 견본 (한산만, docs/research/enemy_answers.md): 계산 규칙과 봇 넷 비교표.

const SEEDS := [1, 2]


func after_test() -> void:
	EnemyAnswer.enabled = true


func test_right_answer_is_faster_others_only_slower() -> void:
	var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	e.data = preload("res://data/enemies/waegun_heavy.tres")
	add_child(auto_free(e))
	var a := e.data.answer
	assert_str(a.kind).is_equal(EnemyAnswer.CHARGE)
	assert_int(EnemyAnswer.scaled(e, EnemyAnswer.CHARGE, 10)).is_equal(roundi(10 * a.mult))
	assert_int(EnemyAnswer.scaled(e, EnemyAnswer.COMBO, 10)).is_equal(roundi(10 * a.others_mult))  # 다른 수는 느릴 뿐 (못 잡는 게 아니다)
	assert_float(a.others_mult).is_greater_equal(0.2)
	EnemyAnswer.enabled = false
	assert_int(EnemyAnswer.scaled(e, EnemyAnswer.CHARGE, 10)).is_equal(10)
	assert_str(EnemyAnswer.of_slot(SkillCaster.Slot.TAP)).is_equal(EnemyAnswer.COMBO)  # 4타 마무리 = 연타 쪽


## 봇 넷 × 정답 표 켬/끔 × 씨앗 둘 (순신, 한산 섞인 무리). 섞어 쓰기가 정답 표를 켰을 때 가장 빨라야 한다.
func test_mixing_is_fastest_with_answers() -> void:
	var names := ["연타만", "내닫기만", "모으기만", "섞어 쓰기"]
	var sums := {true: [0.0, 0.0, 0.0, 0.0], false: [0.0, 0.0, 0.0, 0.0]}
	for on in [false, true]:
		EnemyAnswer.enabled = on
		for b in 4:
			for s in SEEDS:
				var sim := AnswerSim.new(self)
				await sim.setup(null, s)
				sim.spawn_mix()
				var r := sim.run_answers(b as AnswerSim.AnswerBot)
				print("[answers] %s %-6s seed %d: %s %.1fs, damage %d, counters %d, charges %d" % [
					"on " if on else "off", names[b], s, "CLEAR" if r["cleared"] else "NOT", r["time"], r["damage"], r["counters"], r["charges"]])
				sums[on][b] += float(r["time"])
				sim.free_all()
	for on in [false, true]:
		print("[answers] %s sum: %s" % ["on " if on else "off", ", ".join(range(4).map(func(i: int) -> String: return "%s %.1fs" % [names[i], sums[on][i]]))])
	var on_sums: Array = sums[true]
	for b in 3:
		assert_float(on_sums[3]).override_failure_message("섞어 쓰기 %.1f vs %s %.1f" % [on_sums[3], names[b], on_sums[b]]).is_less(on_sums[b])
