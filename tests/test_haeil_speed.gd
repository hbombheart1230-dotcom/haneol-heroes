extends GdUnitTestSuite
## 순신 4번 해일검기: 많이 모을수록 빠르게 지나간다 (사용자 2026-11-27 "커진 만큼 빨리 지나가게").
## 가는 거리(조준 길)·판정 폭·피해는 그대로, 지나가는 시간만 짧아진다.

const YI := preload("res://data/heroes/yi_sun_sin.tres")


func _haeil() -> HaeilSkill:
	return YI.kit.charge as HaeilSkill


func test_faster_with_charge_and_proportional_to_size() -> void:
	var h := _haeil()
	assert_float(h.speed_size_power).is_greater(0.0)
	assert_float(h.speed_at(0.0)).is_equal_approx(h.speed, 0.01)  # 바로 놓으면 예전 그대로
	var prev := h.speed_at(0.0)
	for c in [0.25, 0.5, 0.75, 1.0]:
		var v := h.speed_at(c)
		assert_float(v).is_greater(prev)
		prev = v
	var ratio := h.size_at(1.0) / h.size_at(0.0)
	assert_float(h.speed_at(1.0) / h.speed).is_equal_approx(pow(ratio, h.speed_size_power), 0.001)


func test_reach_width_damage_unchanged_only_time_shorter() -> void:
	var h := _haeil()
	var old := h.duplicate() as HaeilSkill
	old.speed_size_power = 0.0
	for c in [0.0, 0.5, 1.0]:
		assert_float(h.aim_length(c)).is_equal_approx(old.aim_length(c), 0.5)  # 가는 거리 그대로
		assert_float(h.aim_width(c)).is_equal_approx(old.aim_width(c), 0.01)
		assert_float(h.wave_lifetime(c)).is_less_equal(old.wave_lifetime(c) + 0.0001)
	assert_float(h.wave_lifetime(1.0)).is_less(old.wave_lifetime(1.0) * 0.7)  # 다 모으면 확실히 짧게
	assert_int(h.charge_scaling.damage_at(h.min_damage, h.max_damage, 1.0)).is_equal(
		old.charge_scaling.damage_at(old.min_damage, old.max_damage, 1.0))
