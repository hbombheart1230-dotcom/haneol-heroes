extends GdUnitTestSuite
## 적 행동: 공격권·둘레 돌기, 처벌 시간, 군대별 버릇(물러나며 쏘기·돌진·일제 사격·방패·뛰기·매복·혀), 무리 이벤트, 정예 변종.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func before_test() -> void:
	AttackTokens.clear()


func after_test() -> void:
	AttackTokens.clear()
	Feedback.instance = null


func _ai() -> EnemyAIData:
	var ai := EnemyAIData.new()
	ai.max_melee_tokens = 2
	return ai


func _enemy(path: String, pos: Vector2 = Vector2(100, 0)) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = load(path)
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	return e


func test_tokens_limit_and_release() -> void:
	assert_bool(AttackTokens.request(1, 2)).is_true()
	assert_bool(AttackTokens.request(2, 2)).is_true()
	assert_bool(AttackTokens.request(3, 2)).is_false()
	assert_bool(AttackTokens.request(1, 2)).is_true()  # 이미 가짐
	AttackTokens.release(1)
	assert_bool(AttackTokens.request(3, 2)).is_true()
	assert_int(AttackTokens.count()).is_equal(2)


func test_without_token_enemy_circles_instead_of_charging() -> void:
	var ai := _ai()
	var a := EnemyBrain.new(ai, null, 1, true)
	var b := EnemyBrain.new(ai, null, 2, true)
	var c := EnemyBrain.new(ai, null, 3, true)
	assert_vector(a.steer(Vector2.RIGHT, 200.0)).is_equal(Vector2.RIGHT)
	assert_vector(b.steer(Vector2.RIGHT, 200.0)).is_equal(Vector2.RIGHT)
	var d: Vector2 = c.steer(Vector2.RIGHT, ai.hold_radius)
	assert_float(absf(d.dot(Vector2.RIGHT))).is_less(0.1)  # 고리 위: 옆걸음만
	assert_float(absf(d.y)).is_greater(0.1)
	# 멀어지면 공격권을 돌려준다
	a.steer(Vector2.RIGHT, ai.release_radius + 10.0)
	assert_bool(AttackTokens.has(1)).is_false()
	assert_vector(c.steer(Vector2.RIGHT, 200.0)).is_equal(Vector2.RIGHT)


func test_ranged_and_bosses_ignore_tokens() -> void:
	var ai := _ai()
	ai.max_melee_tokens = 0
	var r := EnemyBrain.new(ai, null, 9, false)
	assert_vector(r.steer(Vector2.RIGHT, 100.0)).is_equal(Vector2.RIGHT)


func test_punish_window_and_front_guard() -> void:
	var ai := EnemyAIData.new()
	var beh := EnemyBehaviourData.new()
	beh.front_guard_deg = 120.0
	beh.front_guard_mult = 0.3
	var b := EnemyBrain.new(ai, beh, 1, true)
	var atk := EnemyAttack.new(EnemyAttackData.new())
	assert_float(b.damage_mult(atk, Vector2.RIGHT, Vector2.RIGHT, 1.0)).is_equal_approx(0.3, 0.001)  # 정면
	assert_float(b.damage_mult(atk, Vector2.RIGHT, Vector2.LEFT, 1.0)).is_equal_approx(1.0, 0.001)  # 뒤
	atk.state = EnemyAttack.State.RECOVER
	assert_float(b.damage_mult(atk, Vector2.RIGHT, Vector2.LEFT, 1.0)).is_equal_approx(ai.punish_mult, 0.001)


func test_kite_while_aiming_backs_off() -> void:
	var d := EnemyAttackData.new()
	d.kind = EnemyAttackData.Kind.SHOOT
	d.kite_while_aiming = 0.7
	var atk := EnemyAttack.new(d)
	atk.state = EnemyAttack.State.WINDUP
	var b := EnemyBrain.new(EnemyAIData.new(), null, 1, false)
	assert_vector(b.busy_dir(atk, Vector2.RIGHT)).is_equal(Vector2(-0.7, 0))


func test_hop_arcs_and_lands() -> void:
	var beh := EnemyBehaviourData.new()
	beh.style = EnemyBehaviourData.Style.HOP
	var b := EnemyBrain.new(EnemyAIData.new(), beh, 0, true)
	var v := Vector2.ZERO
	for i in 200:
		v = b.tick_hop(0.016, Vector2.RIGHT, false)
		if b.is_hopping():
			break
	assert_bool(b.is_hopping()).is_true()
	assert_float(v.length()).is_greater(100.0)
	for i in 10:
		b.tick_hop(0.016, Vector2.RIGHT, false)
	assert_float(b.hop_lift()).is_greater(0.0)


func test_ambush_hidden_until_close() -> void:
	var beh := EnemyBehaviourData.new()
	beh.style = EnemyBehaviourData.Style.AMBUSH
	var b := EnemyBrain.new(EnemyAIData.new(), beh, 0, false)
	b.steer(Vector2.RIGHT, 600.0)
	assert_float(b.speed_k).is_equal(beh.ambush_speed_mult)
	assert_float(b.alpha()).is_equal(beh.ambush_alpha)
	b.steer(Vector2.RIGHT, beh.ambush_range - 1.0)
	assert_float(b.alpha()).is_equal(1.0)


func test_volley_clock() -> void:
	var ai := EnemyAIData.new()
	assert_bool(EnemyBrain.volley_open(ai, ai.volley_interval * 3.0 + 0.05)).is_true()
	assert_bool(EnemyBrain.volley_open(ai, ai.volley_interval * 3.0 + ai.volley_window + 0.1)).is_false()
	var d := EnemyAttackData.new()
	d.kind = EnemyAttackData.Kind.SHOOT
	d.volley = true
	assert_bool(d.volley).is_true()


func test_missed_charge_has_long_recovery_and_pull_shape() -> void:
	var d := EnemyAttackData.new()
	d.kind = EnemyAttackData.Kind.CHARGE
	d.windup = 0.1
	d.recovery = 0.2
	d.miss_recovery = 1.0
	d.trigger_range = 500.0
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.global_position = Vector2(0, 0)
	var atk := EnemyAttack.new(d)
	atk.tick(0.016, Vector2(300, 0), p)  # 예고 시작
	p.global_position = Vector2(0, 400)  # 옆으로 비킴
	var r := atk.tick(0.2, Vector2(300, 0), p)
	assert_int(r).is_equal(EnemyAttack.Result.MISSED)
	assert_float(atk._timer).is_equal(1.0)
	var pull := EnemyAttackData.new()
	pull.kind = EnemyAttackData.Kind.PULL
	var pa := EnemyAttack.new(pull)
	pa.aim_origin = Vector2.ZERO
	pa.aim_dir = Vector2.RIGHT
	assert_bool(pa.contains(Vector2(200, 0))).is_true()
	assert_bool(pa.contains(Vector2(200, 300))).is_false()


func test_army_behaviours_in_data() -> void:
	var js := _enemy("res://data/enemies/jurchen_soldier.tres")
	assert_int(js.attack.data.kind).is_equal(EnemyAttackData.Kind.CHARGE)
	assert_float(js.attack.data.miss_overshoot).is_greater(0.0)
	var wg := _enemy("res://data/enemies/waegun_gunner.tres")
	assert_bool(wg.attack.data.volley).is_true()
	var ar := _enemy("res://data/enemies/archer.tres")
	assert_float(ar.attack.data.kite_while_aiming).is_greater(0.0)
	var wh: EnemyData = load("res://data/enemies/waegun_heavy.tres")
	assert_float(wh.behaviour.front_guard_deg).is_greater(0.0)
	var gh: EnemyData = load("res://data/enemies/cc_grasshopper.tres")
	assert_int(gh.behaviour.style).is_equal(EnemyBehaviourData.Style.HOP)
	var mt: EnemyData = load("res://data/enemies/cc_mantis.tres")
	assert_int(mt.behaviour.style).is_equal(EnemyBehaviourData.Style.AMBUSH)
	var fr := _enemy("res://data/enemies/cc_frog.tres")
	var kinds := fr.attack.patterns.map(func(x: EnemyAttackData) -> int: return x.kind)
	assert_bool(kinds.has(EnemyAttackData.Kind.PULL)).is_true()


func test_frog_tongue_pulls_player() -> void:
	var fr := _enemy("res://data/enemies/cc_frog.tres", Vector2(400, 0))
	var p: Player = auto_free(Player.new())
	add_child(p)
	fr.target = p
	fr.attack.set_patterns([fr.attack.patterns[1]])
	fr.attack.aim_dir = Vector2.LEFT
	fr._on_attack_result(EnemyAttack.Result.HIT)
	assert_float(p._recoil_vel.x).is_greater(0.0)  # 개구리(오른쪽) 쪽으로


func test_frontal_hit_on_shield_heavy_is_reduced() -> void:
	var p: Player = auto_free(Player.new())
	add_child(p)
	var wh := _enemy("res://data/enemies/waegun_heavy.tres", Vector2(100, 0))
	wh.target = p
	wh._update_damage_mult()
	assert_float(wh.damage_mult()).is_less(0.5)
	var before := wh.health.current
	wh.health.damage(20)
	assert_int(before - wh.health.current).is_less(10)


func test_horde_director_cycles_and_places() -> void:
	var ai := EnemyAIData.new()
	var hd := HordeDirector.new(ai)
	assert_int(hd.tick(ai.horde_first - 1.0)).is_equal(-1)
	assert_int(hd.tick(ai.horde_first)).is_equal(HordeDirector.Kind.RING)
	assert_int(hd.tick(ai.horde_first + 1.0)).is_equal(-1)
	assert_int(hd.tick(ai.horde_first + ai.horde_interval)).is_equal(HordeDirector.Kind.WALL)
	assert_int(hd.tick(ai.horde_first + ai.horde_interval * 2.0)).is_equal(HordeDirector.Kind.SWARM)
	var ring := hd.ring_points(Vector2.ZERO)
	assert_int(ring.size()).is_equal(ai.ring_count)
	assert_float(ring[0].length()).is_equal_approx(ai.ring_radius, 0.01)
	var wall := hd.wall_points(Vector2.ZERO, Vector2.RIGHT)
	assert_int(wall.size()).is_equal(ai.wall_count)
	for q in wall:
		assert_float(q.x).is_equal_approx(ai.wall_distance, 0.01)


func _spawner() -> EnemySpawner:
	var p: Player = auto_free(Player.new())
	add_child(p)
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	sp.target = p
	sp.spawn_table = [load("res://data/enemies/jurchen_soldier.tres")] as Array[EnemyData]
	add_child(sp)
	sp.set_physics_process(false)  # 시간 진행 없이 직접 부른다 (add_child 뒤에 꺼야 남는다)
	return sp


func test_horde_events_spawn_their_shapes() -> void:
	var sp := _spawner()
	var ai := Enemy.ai_data()
	assert_int(sp.start_horde(HordeDirector.Kind.RING)).is_equal(ai.ring_count)
	assert_int(sp.start_horde(HordeDirector.Kind.WALL)).is_equal(ai.wall_count)
	var swept := 0
	for c in sp.get_children():
		if c is Enemy and (c as Enemy).brain.sweep_left > 0.0:
			swept += 1
	assert_int(swept).is_equal(ai.wall_count)
	var before := sp.alive_count()
	assert_int(sp.start_horde(HordeDirector.Kind.SWARM)).is_equal(ai.swarm_count)
	var last := sp.get_child(sp.get_child_count() - 1) as Enemy
	assert_float(last.size_mult).is_equal(ai.swarm_scale)
	assert_int(sp.alive_count()).is_equal(before + ai.swarm_count)


func test_elite_affix_applies_and_splitting_splits() -> void:
	var sp := _spawner()
	var split: EliteAffixData
	for a in Enemy.ai_data().elite_affixes:
		if a.split_count > 0:
			split = a
	assert_object(split).is_not_null()
	var d: EnemyData = load("res://data/enemies/jurchen_elite.tres")
	var e := sp.spawn_at(d, Vector2(300, 0), func(en: Enemy) -> void: en.affix = split)
	assert_object(e.affix).is_same(split)
	var n := sp.alive_count()
	e.health.kill()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(sp.alive_count()).is_equal(n - 1 + split.split_count)
	var armored: EliteAffixData
	for a in Enemy.ai_data().elite_affixes:
		if a.damage_taken_mult < 1.0:
			armored = a
	var tough := sp.spawn_at(d, Vector2(-300, 0), func(en: Enemy) -> void: en.affix = armored)
	tough._update_damage_mult()
	assert_float(tough.damage_mult()).is_equal_approx(armored.damage_taken_mult, 0.001)


func test_horde_and_splits_respect_extra_cap() -> void:
	# Codex 36997a5: 무리·분열이 동시 최대 수를 끝없이 넘지 않게
	var sp := _spawner()
	sp.max_alive = 0
	var cap := Enemy.ai_data().horde_extra_alive
	var made := 0
	for i in 4:
		made += sp.start_horde(HordeDirector.Kind.SWARM)
	assert_int(made).is_equal(cap)
	assert_int(sp.alive_count()).is_equal(cap)


func test_no_split_after_run_ends() -> void:
	var sp := _spawner()
	var split: EliteAffixData
	for a in Enemy.ai_data().elite_affixes:
		if a.split_count > 0:
			split = a
	var e := sp.spawn_at(load("res://data/enemies/jurchen_elite.tres"), Vector2(300, 0), func(en: Enemy) -> void: en.affix = split)
	var n := sp.alive_count()
	sp.active = false  # 판 끝
	e.health.kill()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(sp.alive_count()).is_equal(n - 1)


func test_volley_shooters_ignore_windup_cap() -> void:
	var d := EnemyAttackData.new()
	d.kind = EnemyAttackData.Kind.SHOOT
	d.volley = true
	d.trigger_range = 1000.0
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var was := EnemyAttack.active_windups
	EnemyAttack.active_windups = EnemyAttack.max_concurrent
	var atk := EnemyAttack.new(d)  # ai 없음 = 박자 제한 없음
	atk.tick(0.016, Vector2(100, 0), p)
	assert_int(atk.state).is_equal(EnemyAttack.State.WINDUP)
	atk.cancel()
	EnemyAttack.active_windups = was


func test_ambusher_reveals_before_it_can_strike() -> void:
	var mt: EnemyData = load("res://data/enemies/cc_mantis.tres")
	assert_float(mt.behaviour.ambush_range).is_greater(mt.behaviour.attack.trigger_range)
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var e := _enemy("res://data/enemies/cc_mantis.tres", Vector2(mt.behaviour.attack.trigger_range - 10.0, 0))
	e.target = p
	e.attack._cooldown = 0.0
	e._physics_process(0.016)
	assert_bool(e.attack.is_busy()).is_true()
	assert_float(e.brain.alpha()).is_equal(1.0)
