extends GdUnitTestSuite
## 근접 연타 실제 전진 (사용자 2026-11-25): 타마다 몸이 대상 쪽으로 (거리는 영웅 Resource, 뒤 타일수록 크게).
## 제한: 대상 몸에서 멈춤 (뚫지 않음), 대상이 없으면 조금만, 이동 막대가 반대면 0, 적 예고·위험 칸(StepGuard) 안으로는 안 들어감.
## 사임당·세종은 값이 없어 예전 그대로 (기본값 = 끔).

const YI := preload("res://data/heroes/yi_sun_sin.tres")


func test_want_step_rules() -> void:
	var d := YI.attack
	var r := Vector2.RIGHT
	assert_float(ComboSteps.want_step(d, 1, r, true, Vector2.ZERO)).is_equal(d.step_in_px[0])
	assert_float(ComboSteps.want_step(d, 0, r, true, Vector2.ZERO)).is_equal(d.finisher_step_in_px)  # 마무리
	assert_float(ComboSteps.want_step(d, 2, r, false, Vector2.ZERO)).is_equal_approx(d.step_in_px[1] * d.step_in_no_target_mult, 0.01)
	assert_float(ComboSteps.want_step(d, 2, r, true, Vector2.LEFT)).is_equal(0.0)  # 막대가 반대쪽
	assert_float(ComboSteps.want_step(d, 2, r, true, Vector2.UP)).is_equal(d.step_in_px[1])  # 옆은 그대로
	assert_float(ComboSteps.step_in(60.0, d.step_in_max, 12.0, false)).is_equal(12.0)  # 적 몸에서 멈춤


## 기본값(사임당·세종): 대상 없음·막대 반대여도 예전과 같다, 마무리 전진 없음.
func test_defaults_keep_old_behaviour() -> void:
	for id in ["sejong", "shin_saimdang"]:
		var d := (load("res://data/heroes/%s.tres" % id) as HeroData).attack
		assert_float(d.finisher_step_in_px).override_failure_message(id).is_equal(0.0)
		assert_float(d.step_in_no_target_mult).override_failure_message(id).is_equal(1.0)
		assert_float(ComboSteps.want_step(d, 2, Vector2.RIGHT, true, Vector2.LEFT)).override_failure_message(id) \
			.is_equal(ComboSteps.at(d.step_in_px, 2, 0.0))


class Danger extends Node:
	var rect := Rect2(40, -50, 100, 100)
	func step_danger_at(p: Vector2, _r: float) -> bool:
		return rect.has_point(p)


func test_step_guard_keeps_out_of_danger() -> void:
	assert_float(StepGuard.safe_px(get_tree(), Vector2.ZERO, Vector2.RIGHT, 48.0, 20.0)).is_equal(48.0)  # 위험 장치 없음
	var z: Danger = auto_free(Danger.new())
	add_child(z)
	z.add_to_group(StepGuard.GROUP)
	assert_float(StepGuard.safe_px(get_tree(), Vector2.ZERO, Vector2.RIGHT, 48.0, 20.0)).is_equal(24.0)  # 끝점이 위험 → 절반
	z.rect = Rect2(10, -50, 100, 100)
	assert_float(StepGuard.safe_px(get_tree(), Vector2.ZERO, Vector2.RIGHT, 48.0, 20.0)).is_equal(0.0)
	assert_float(StepGuard.safe_px(get_tree(), Vector2.ZERO, Vector2.UP, 48.0, 20.0)).is_equal(48.0)
	z.remove_from_group(StepGuard.GROUP)
