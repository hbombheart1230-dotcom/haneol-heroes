extends GdUnitTestSuite
## 잡몹이 경직에 묶여 아무것도 못 하지 않게 (사임당 "무한 스턴", 측정: tests/test_hero_difficulty_sim.gd):
##  ① 경직이 풀린 뒤 stagger_guard초는 다시 경직되지 않는다  ② 끊긴(넘어져 버린) 예고 다음 예고는 끊기지 않는다
##  ③ 넘어짐 재무장 3초  ⑤ 한 번에 여럿을 베면 경직이 짧다 (한 놈 연타는 그대로).
## 그리고 무대 근접 잡몹의 공격 시작 거리는 왜군 창병과 같은 170px (사임당 230px 붓질에 늘 거리 밖이던 것).


func _reaction() -> HitReaction:
	return HitReaction.new(HitReactionData.new(), HitReaction.Tier.TRASH)


func test_no_new_stagger_right_after_one_ends() -> void:
	var r := _reaction()
	r.on_hit(5, 30, Vector2.RIGHT)
	assert_bool(r.is_staggered()).is_true()
	r.tick(r.stagger_time() + 0.01)
	assert_bool(r.is_staggered()).is_false()
	r.on_hit(5, 30, Vector2.RIGHT)
	assert_bool(r.is_staggered()).is_false()  # 지키는 동안: 피해·움찔은 받지만 경직은 없다
	r.tick(r.data.stagger_guard + 0.01)
	r.on_hit(5, 30, Vector2.RIGHT)
	assert_bool(r.is_staggered()).is_true()


func test_continuous_stagger_is_capped() -> void:
	var r := _reaction()
	var t := 0.0
	while t < r.data.stagger_chain_max + 0.2:
		r.on_hit(5, 30, Vector2.RIGHT)  # 쉬지 않고 맞아도
		r.tick(0.05)
		t += 0.05
	assert_bool(r.is_staggered()).is_false()  # 이어진 경직은 chain_max까지


func test_crowd_hit_staggers_shorter() -> void:
	var r := _reaction()
	assert_float(r.crowd_mult(1)).is_equal(1.0)
	assert_float(r.crowd_mult(3)).is_less(1.0)
	assert_float(r.crowd_mult(30)).is_equal_approx(r.data.crowd_stagger_min, 0.001)
	r.on_hit(5, 30, Vector2.RIGHT, 5)
	assert_float(r.stagger_left).is_equal_approx(r.stagger_time() * r.crowd_mult(5), 0.001)


func test_interrupted_attack_guards_next_windup() -> void:
	var d := EnemyAttackData.new()
	d.windup = 0.8
	d.cooldown = 0.5
	d.trigger_range = 500.0
	var a := EnemyAttack.new(d, 0.0)
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.set_physics_process(false)
	a.tick(0.016, Vector2(100, 0), p)
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)
	a.interrupt(0.1, 0.0, true)  # 끊김 (재무장 시간 0)
	assert_bool(a.guard_next).is_true()
	var t := 0.0
	while a.state != EnemyAttack.State.WINDUP and t < 2.0:
		a.tick(0.016, Vector2(100, 0), p)
		t += 0.016
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)
	assert_bool(a.can_interrupt()).is_false()  # 다음 예고는 지켜진다
	assert_bool(a.guard_next).is_false()


func test_rules_are_data() -> void:
	var d := ImpactFeelData.new()
	assert_bool(d.interrupt_guard_next).is_true()
	assert_float(d.down_rearm).is_equal(3.0)


func test_stage_melee_trash_reach_matches_hansan_spear() -> void:
	var spear: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	for id in ["chaser", "jurchen_soldier", "cc_mouse"]:
		var d: EnemyData = load("res://data/enemies/%s.tres" % id)
		assert_float(d.attack.trigger_range).override_failure_message(id).is_equal(spear.attack.trigger_range)
