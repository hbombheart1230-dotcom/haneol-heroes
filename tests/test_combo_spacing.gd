extends GdUnitTestSuite
## 연타 간격 A안 (사용자: "지금 평타사이의 간격이 너무 짧아서 애매한 느낌인데?"): 타 사이를 늘리고 (순신 0.40·0.42·0.60초,
## 광개토 0.45·0.50·0.70, 사임당 순신과 같게, 세종 글자 연사는 한 바퀴 그대로 고르게) 초당 피해는 그대로.
## 한 바퀴 피해 = 한 타 × (1 + 1 + 3타 배율), 탭 한 바퀴 = 간격 셋의 합, 자동 평타 한 바퀴 = 평타 간격 × 3.

const OLD_MULTS := [0.55, 0.6, 1.0]
## 영웅: [예전 간격, 예전 한 타 피해, 바라는 간격 (1→2, 2→3, 3→1), 탭 초당 피해 비율 상한]. 세종은 글자 연사 (ranged).
## 순신은 뒤에 사용자가 다시 정함 (2026-11-24: "1타와 2타 사이에 정적이 있다 → 끝 동작을 짧게, 휘두르기 조금 빠르게",
## PR #116), 그 뒤 쾌검 (2026-11-24: "공속을 좀 더 빠르게, 1·2·3타 사이 멈춤을 더 줄여 줘"): 0.26·0.28·0.45초, 휘두르기 1.5배,
## 평타 간격 0.46, 한 타 13 (졸병 26이 두 타에 죽는 최소값, 메인 결정: "순신이 약해 보인다"가 되살아나지 않게)
## → 탭 초당 피해 약 30% 오름 (우두머리 세션이 순신 궁합 배율로 우두머리전 길이를 다시 맞춤).
## 그 뒤 (2026-11-24 시험판 07f0d8f: "2타 3타 사이 멈칫 없애고 공격속도 더"): 0.25·0.25·0.25 고르게 (평타 간격 0.36: 자동 평타도 같은 비율로 빨라짐), 3타 모으기 0,
## 한 타 13 → 10 (자동 평타 초당 피해 그대로, 고정 틱 탭 초당 피해 54.7 → 52.6). 4타 값(쿨타임·동작)은 4타 세션 몫.
const HEROES := {
	"yi_sun_sin": [0.55, 12, [0.25, 0.25, 0.25], 1.35],
	"gwanggaeto": [0.8, 22, [0.45, 0.50, 0.70], 1.05],
	"shin_saimdang": [0.6, 10, [0.40, 0.42, 0.60], 1.05],
}


func _gaps(interval: float, mults: Array) -> Array:  # [1→2, 2→3, 3→1]
	return [interval * mults[1], interval * mults[2], interval * mults[0]]


func _sum(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s


func test_melee_gaps_match_plan_and_dps_holds() -> void:
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		var d := h.attack
		var plan: Array = HEROES[id]
		var gaps := _gaps(d.melee_interval, Array(d.step_gap_mults))
		for i in 3:
			assert_float(gaps[i]).override_failure_message("%s gap %d" % [id, i]).is_equal_approx(plan[2][i], 0.01)
		var hits := 2.0 + d.heavy_damage_mult
		var old_tap: float = plan[1] * hits / _sum(_gaps(plan[0], OLD_MULTS))
		var new_tap := d.melee_damage * hits / _sum(gaps)
		var old_auto: float = plan[1] * hits / (plan[0] * 3.0)
		var new_auto := d.melee_damage * hits / (d.melee_interval * 3.0)
		assert_float(new_tap / old_tap).override_failure_message("%s tap dps %.3f" % [id, new_tap / old_tap]).is_between(0.95, plan[3])
		assert_float(new_auto / old_auto).override_failure_message(id + " auto dps").is_between(0.95, plan[3])  # 승인된 영웅별 상한 (순신 쾌검 +30%)
		assert_float(_sum(gaps)).override_failure_message(id + " tap still faster than auto").is_less(d.melee_interval * 3.0)
		# 한 타 동작이 간격 안에서 끝까지 보인다 (실제 재생 길이 = 시트 attack 길이 ÷ 휘두르기 배율 ≤ 가장 짧은 간격)
		var sheet := h.sprite_sheet
		var i := sheet.anim_names.find("attack")
		var speed := h.blade_bite.swing_speed if h.blade_bite and h.blade_bite.enabled else 1.0
		var anim_len := sheet.frame_count("attack") / maxf(sheet.fps[i], 1.0) / speed
		assert_float(anim_len).override_failure_message(id + " anim cut").is_less_equal(gaps.min() + 0.001)


## 세종 글자 연사: 고른 박자 (한 바퀴 비율 그대로), 초당 피해 그대로.
## 사용자 7ce32eb "세종은 아직 공속이 너무 빠르다" → 평타 간격 0.55 → 0.64 (약 16% 느리게), 한 발 12 → 14 (초당 피해 그대로):
## 0.36·0.40·0.42 → 0.42·0.47·0.49.
func test_sejong_glyph_taps_even_out_same_round() -> void:
	var d := (load("res://data/heroes/sejong.tres") as HeroData).attack
	var gaps := _gaps(d.ranged_interval, Array(d.step_gap_mults))
	assert_float(gaps[0]).is_equal_approx(0.42, 0.01)
	assert_float(gaps[1]).is_equal_approx(0.47, 0.01)
	assert_float(gaps[2]).is_equal_approx(0.49, 0.01)
	assert_float(d.ranged_damage / d.ranged_interval).is_equal_approx(12.0 / 0.55, 0.5)  # 초당 피해 그대로
	assert_float(_sum(gaps)).is_equal_approx(_sum(_gaps(d.ranged_interval, OLD_MULTS)), 0.02)
