extends GdUnitTestSuite
## 적 무게 등급 × 타 세기 (사용자 2026-11-25 "적이 맞는 쪽 반응"): 가벼운 적은 크게 젖혀지고 멀리 밀려 날아가며 돌고,
## 묵직한 적은 무릎을 굽혀 버티며 조금만 젖혀지고, 정예는 4타·기술에만 맞는 동작. 1·2타 < 3타 < 4타·기술.
## 무게가 없으면 예전 그대로.

const LIGHT := preload("res://data/enemies/weight/light.tres")
const HEAVY := preload("res://data/enemies/weight/heavy.tres")
const ELITE := preload("res://data/enemies/weight/elite.tres")
const P := HitReaction.Power


func _hit(w: HitWeightData, power: int, tier := HitReaction.Tier.TRASH, applied := 10, max_hp := 1000) -> HitReaction:
	var r := HitReaction.new(HitReactionData.new(), tier)
	r.weight = w
	r.on_hit(applied, max_hp, Vector2.RIGHT, 1, power)
	return r


func test_power_order_and_weights() -> void:
	var lean := func(w: HitWeightData, p: int) -> float: return _hit(w, p).lean_offset().length()
	for w: HitWeightData in [LIGHT, HEAVY, ELITE]:
		assert_float(lean.call(w, P.LIGHT)).is_less(lean.call(w, P.HEAVY))
		assert_float(lean.call(w, P.HEAVY)).is_less(lean.call(w, P.BIG))
	assert_float(lean.call(LIGHT, P.BIG)).is_greater(lean.call(HEAVY, P.BIG) * 1.5)  # 가벼운 적이 훨씬 크게 젖혀진다
	var sq_light := 1.0 - _hit(LIGHT, P.BIG).squash_mult().y
	var sq_heavy := 1.0 - _hit(HEAVY, P.BIG).squash_mult().y
	assert_float(sq_heavy / maxf(_hit(HEAVY, P.BIG).lean_offset().length(), 0.01)).is_greater(sq_light / maxf(_hit(LIGHT, P.BIG).lean_offset().length(), 0.01))  # 묵직한 적: 젖힘보다 눌림 (버팀)
	assert_float(HEAVY.lean_time_mult).is_greater(LIGHT.lean_time_mult)  # 천천히 돌아온다
	assert_float(LIGHT.knockback_mult).is_greater(HEAVY.knockback_mult)


func test_no_weight_is_old_behaviour() -> void:
	var r := _hit(null, P.BIG)
	var d := HitReactionData.new()
	assert_float(r.lean_offset().length()).is_equal_approx(d.lean_px, 0.01)
	assert_float(r.launch_spin(0.5, 1.0)).is_equal(0.0)


func test_elite_plays_hit_anim_only_on_big_hits() -> void:
	assert_bool(_hit(ELITE, P.LIGHT, HitReaction.Tier.ELITE).shows_hit_anim()).is_false()
	assert_bool(_hit(ELITE, P.HEAVY, HitReaction.Tier.ELITE).shows_hit_anim()).is_false()
	assert_bool(_hit(ELITE, P.BIG, HitReaction.Tier.ELITE).shows_hit_anim()).is_true()
	assert_bool(_hit(null, P.BIG, HitReaction.Tier.ELITE).shows_hit_anim()).is_false()  # 예전: 1/16 이상일 때만


func test_light_lifts_higher_and_spins_when_launched() -> void:
	var im := ImpactFeelData.new()
	var l := _hit(LIGHT, P.HEAVY)
	l.knock_down(im)
	var h := _hit(null, P.HEAVY)
	h.knock_down(im)
	l.tick(im.down_lift_time * 0.5)
	h.tick(im.down_lift_time * 0.5)
	assert_float(l.down_lift()).is_greater(h.down_lift())
	assert_float(absf(l.launch_spin(1.0, 1.0))).is_greater(PI)
	assert_float(_hit(HEAVY, P.BIG).launch_spin(1.0, 1.0)).is_equal(0.0)


## 한산 왜군에 등급이 붙어 있다.
func test_hansan_enemies_have_weights() -> void:
	var want := {"waegun_soldier": LIGHT, "waegun_gunner": LIGHT, "waegun_heavy": HEAVY, "waegun_captain": ELITE,
		"waegun_drummer": ELITE, "waegun_elite": ELITE, "waegun_gunner_captain": ELITE, "waegun_commander": ELITE}
	for id: String in want:
		var d: EnemyData = load("res://data/enemies/%s.tres" % id)
		assert_object(d.hit_weight).override_failure_message(id).is_same(want[id])
