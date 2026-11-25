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


## 새 동작 (Meshy, 사용자 "받아" 2026-11-25): 가벼운 적 날아감·죽음, 무사 넘어짐·버팀·죽음, 정예 넘어짐 (갑옷 깨질 때).
func test_new_reaction_anims_and_heavy_down() -> void:
	for id in ["waegun_soldier", "waegun_gunner"]:
		var sh := (load("res://data/enemies/%s.tres" % id) as EnemyData).sprite_sheet
		for a in ["fly", "death", "down"]:
			assert_bool(sh.has_anim(a)).override_failure_message("%s %s" % [id, a]).is_true()
	var hv := (load("res://data/enemies/waegun_heavy.tres") as EnemyData).sprite_sheet
	for a in ["death", "hit"]:
		assert_bool(hv.has_anim(a)).override_failure_message("heavy " + a).is_true()
	assert_bool((load("res://data/enemies/waegun_elite.tres") as EnemyData).sprite_sheet.has_anim("down")).is_true()
	assert_int(HEAVY.down_power).is_equal(-1)  # 무사 넘어짐은 껐다: 넘어진 동안 공격이 멈춰 반격 틈이 줄어 한산 물결이 +12초 (2026-11-25)
	assert_int(LIGHT.down_power).is_equal(-1)
	assert_int(ELITE.down_power).is_equal(-1)  # 정예는 갑옷이 깨질 때만 (EnemyHits.on_poise)


## down_power: 슈퍼아머 적도 그 타 세기부터 넘어진다 (지금 한산 무사는 끔, 장치는 남김 — 무게 등급 사본으로 지킨다).
func test_down_power_knocks_armored_trash() -> void:
	var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	var d: EnemyData = preload("res://data/enemies/waegun_heavy.tres").duplicate()
	d.hit_weight = HEAVY.duplicate()
	d.hit_weight.down_power = HitReaction.Power.BIG
	e.data = d
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.health.max = 9999
	e.health.current = 9999
	e.attack = null
	e.hit_power = HitReaction.Power.HEAVY
	EnemyHits.on_hit(e, true)
	assert_bool(e.reaction.is_down()).is_false()
	e.hit_power = HitReaction.Power.BIG
	EnemyHits.on_hit(e, false)
	assert_bool(e.reaction.is_down()).is_true()


## 졸병·철포병·무사는 처치되면 쓰러지는 동작 (death_hold > 0, 예전엔 0이라 구운 death를 안 썼다).
func test_trash_death_pose_on() -> void:
	for id in ["waegun_soldier", "waegun_gunner", "waegun_heavy"]:
		var d := load("res://data/enemies/%s.tres" % id) as EnemyData
		assert_float(EnemyDeathPose.hold_time(d)).override_failure_message(id).is_greater(0.0)


## 날아감 돌림은 온 바퀴에서 천천히 멈춘다 (끝 각도 = 0과 같음, 끝 빠르기 0).
func test_launch_spin_ends_smoothly() -> void:
	var r := _hit(LIGHT, P.BIG)
	var end := r.launch_spin(1.0, 1.0)
	assert_float(fposmod(end, TAU)).is_equal_approx(0.0, 0.001)
	assert_float(absf(r.launch_spin(1.0, 1.0) - r.launch_spin(0.98, 1.0))).is_less(0.02)
