extends GdUnitTestSuite
## 정답 표 견본 (한산만, docs/research/enemy_answers.md): 계산 규칙과 봇 넷 비교표.

const SEEDS := [1, 2]
## 정답 표를 켰을 때 연타만 봇이 늘어나도 되는 한도 (보통: "알면 편해지는" 정도).
const MAX_COMBO_SLOWDOWN := 1.15


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


const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const NAMES := ["연타만", "내닫기만", "모으기만", "섞어 쓰기"]


## 봇 넷 × 정답 표 켬/끔 × 씨앗 둘, 한산 섞인 무리. 반환 {true: [넷 합], false: [...]} (초).
func _table(hero: String) -> Dictionary:
	var sums := {true: [0.0, 0.0, 0.0, 0.0], false: [0.0, 0.0, 0.0, 0.0]}
	var dmg := {true: [0, 0, 0, 0], false: [0, 0, 0, 0]}
	for on in [false, true]:
		EnemyAnswer.enabled = on
		for b in 4:
			for s in SEEDS:
				var sim := AnswerSim.new(self)
				sim.hero_path = "res://data/heroes/%s.tres" % hero
				await sim.setup(null, s)
				sim.spawn_mix()
				var r := sim.run_answers(b as AnswerSim.AnswerBot)
				sums[on][b] += float(r["time"])
				dmg[on][b] += int(r["damage"])
				sim.free_all()
	EnemyAnswer.enabled = true
	for on in [false, true]:
		print("[answers] %-13s %s: %s" % [hero, "on " if on else "off", ", ".join(range(4).map(func(i: int) -> String:
			return "%s %.1fs (피해 %d)" % [NAMES[i], sums[on][i], dmg[on][i]]))])
	return sums


## 네 영웅 모두: 정답 표를 켜면 섞어 쓰기가 가장 빠르다 ("알면 편해진다"), 연타만은 끌 때보다 크게 길어지지 않는다
## (보통 난도: 강한 강제는 어려움으로 미룬다, 판 길이는 지금과 비슷하게).
func test_mixing_is_fastest_with_answers() -> void:
	var only := OS.get_environment("HH_ONLY_HERO")
	for hero: String in HEROES:
		if only != "" and hero != only:
			continue
		var sums: Dictionary = await _table(hero)
		var on: Array = sums[true]
		var off: Array = sums[false]
		for b in 3:
			assert_float(on[3]).override_failure_message("%s 섞어 쓰기 %.1f vs %s %.1f" % [hero, on[3], NAMES[b], on[b]]).is_less(on[b])
		assert_float(on[0]).override_failure_message("%s 연타만 켬 %.1f vs 끔 %.1f" % [hero, on[0], off[0]]).is_less_equal(off[0] * MAX_COMBO_SLOWDOWN)


## 통하는 수가 읽힌다 (AnswerCue): 맞는 수면 "통!", 갑옷이 다른 수를 덜 받으면 "튕김", 그 밖엔 표시 없음. 붉은 인주색은 안 쓴다.
func test_cue_kind_and_colours() -> void:
	var d := AnswerCue.DEFAULT
	var heavy := preload("res://data/enemies/waegun_heavy.tres").answer
	var gunner := preload("res://data/enemies/waegun_gunner.tres").answer
	assert_int(AnswerCue.hit_kind(heavy, EnemyAnswer.CHARGE, d)).is_equal(AnswerCue.Kind.HIT)
	assert_int(AnswerCue.hit_kind(heavy, EnemyAnswer.COMBO, d)).is_equal(AnswerCue.Kind.DEFLECT)
	assert_int(AnswerCue.hit_kind(gunner, EnemyAnswer.COMBO, d)).is_equal(AnswerCue.Kind.NONE)  # 다른 수도 그대로 받는 적
	assert_int(AnswerCue.hit_kind(preload("res://data/enemies/waegun_soldier.tres").answer, EnemyAnswer.COMBO, d)).is_equal(AnswerCue.Kind.NONE)
	assert_int(AnswerCue.hit_kind(null, EnemyAnswer.COMBO, d)).is_equal(AnswerCue.Kind.NONE)
	for c: Color in [d.hit_color, d.deflect_color]:
		assert_bool(c.r > c.g + 0.25 and c.r > c.b + 0.25).is_false()  # 붉은 계열 아님 (색 규칙 #164)
	for t: String in [d.hit_label, d.deflect_label]:
		assert_bool(RegEx.create_from_string("[A-Za-z]").search(t) == null).is_true()  # 우리말만


## 조작 안내 끝에 한 줄 (처음 하는 사람에게 "통!"이 무엇인지).
func test_tutorial_finish_hint() -> void:
	var t: TutorialData = load("res://data/tutorial/controls.tres")
	assert_str(t.finish_hint).contains("통!")
	assert_float(t.finish_time).is_greater_equal(2.5)
