extends GdUnitTestSuite
## 순신 4번 해일검기: 커진 만큼 빨리 지나간다 (사용자 2026-11-27 "커진 만큼 빨리 지나가게" → 정정 "패를 먹어서 커졌을 때").
## 많이 모을수록, 그리고 큰 해일 패·모습 단계로 커질수록 빠르다. 가는 거리(조준 길)·판정 폭·피해는 그대로, 지나가는 시간만 짧아진다.

const YI := preload("res://data/heroes/yi_sun_sin.tres")


## 패 big장(큰 해일) + 모습 단계 vfx_level lv인 판의 해일검기 (발동 때와 같은 사본).
func _haeil(big: int = 0, lv: int = 0) -> HaeilSkill:
	var b := RunBuild.new()
	b.hero = YI.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	for u in b.hero.upgrade_pool.upgrades:
		if u.id == &"haeil_big":
			for i in big:
				b.apply(u)
	var d := b.hero.kit.charge as HaeilSkill
	d.vfx_level = lv
	return SkillGrowthData.get_default().scaled_def(d) as HaeilSkill


func _old(h: HaeilSkill) -> HaeilSkill:
	var o := h.duplicate() as HaeilSkill
	o.speed_size_power = 0.0
	o.grown_speed_power = 0.0
	return o


func test_faster_with_charge() -> void:
	var h := _haeil()
	assert_float(h.speed_at(0.0)).is_equal_approx(h.speed, 0.5)  # 패 없이 바로 놓으면 예전 그대로
	var prev := h.speed_at(0.0)
	for c in [0.25, 0.5, 0.75, 1.0]:
		var v := h.speed_at(c)
		assert_float(v).is_greater(prev)
		prev = v


## 큰 해일 패·모습 단계로 커져도 다 모은 물결이 지나가는 시간은 패 없을 때와 비슷하다 (±10%), 빠르기는 커진 만큼 오른다.
func test_cards_grow_speed_and_keep_pass_time() -> void:
	var base := _haeil().wave_lifetime(1.0)
	var prev := 0.0
	for big in [0, 1, 2, 3]:
		var h := _haeil(big, 6)
		assert_float(h.wave_lifetime(1.0)).is_between(base * 0.9, base * 1.1)
		assert_float(h.speed_at(1.0)).is_greater(prev)
		prev = h.speed_at(1.0)
		assert_float(h.wave_lifetime(1.0)).is_less(_old(h).wave_lifetime(1.0))


func test_reach_width_damage_unchanged_only_time_shorter() -> void:
	for h in [_haeil(), _haeil(3, 6)]:
		var old := _old(h)
		for c in [0.0, 0.5, 1.0]:
			assert_float(h.aim_length(c)).is_equal_approx(old.aim_length(c), 0.5)  # 가는 거리 그대로
			assert_float(h.aim_width(c)).is_equal_approx(old.aim_width(c), 0.01)
			assert_float(h.wave_lifetime(c)).is_less_equal(old.wave_lifetime(c) + 0.0001)
		assert_int(h.charge_scaling.damage_at(h.min_damage, h.max_damage, 1.0)).is_equal(
			old.charge_scaling.damage_at(old.min_damage, old.max_damage, 1.0))


## 둘 다 0이면 예전 그대로 (빠르기·수명), 빠르기가 0이어도.
func test_zero_power_is_the_old_behaviour() -> void:
	var h := _old(_haeil(2, 3))
	for c in [0.0, 0.5, 1.0]:
		assert_float(h.speed_at(c)).is_equal(h.speed)
		var old_t := h.lifetime * h.charge_scaling.at(h.charge_scaling.reach, c)
		var tail := h.wave_art_size.x * h.tail_lengths * h.size_at(c)
		assert_float(h.wave_lifetime(c)).is_equal_approx(maxf(old_t, (h.exit_px + tail) / h.speed), 0.0001)
	h.speed = 0.0
	assert_float(h.wave_lifetime(1.0)).is_equal_approx(h.lifetime * h.charge_scaling.at(h.charge_scaling.reach, 1.0), 0.0001)


## 수명 갈래(빠져나가기 끔)에서도 가는 거리는 그대로.
func test_reach_branch_keeps_distance() -> void:
	var h := _haeil(2, 6)
	h.exit_px = 0.0
	var old := _old(h)
	for c in [0.0, 0.5, 1.0]:
		assert_float(h.speed_at(c) * h.wave_lifetime(c)).is_equal_approx(old.speed_at(c) * old.wave_lifetime(c), 0.01)
