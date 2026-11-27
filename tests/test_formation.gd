extends GdUnitTestSuite
## 대형 뼈대 (FormationLayout·FormationCycle·물결 차례 넣기): 자리 모양, 사격 주기, 한산 2물결 대형 자리.


func _data(shape: FormationData.Shape, n: int = 5) -> FormationData:
	var d := FormationData.new()
	d.shape = shape
	d.count = n
	d.spacing = 70.0
	d.radius = 300.0
	return d


func test_line_is_perpendicular_to_facing_and_centered() -> void:
	var o := FormationLayout.offsets(_data(FormationData.Shape.LINE), 5, Vector2.DOWN)
	assert_int(o.size()).is_equal(5)
	for p in o:
		assert_float(p.y).is_equal_approx(0.0, 0.001)  # 영웅 쪽(아래)에 수직인 가로 줄
	assert_float(o[0].x + o[4].x).is_equal_approx(0.0, 0.001)
	assert_float(o[1].x - o[0].x).is_equal_approx(70.0, 0.001)


func test_arc_wings_reach_toward_the_hero() -> void:
	var o := FormationLayout.offsets(_data(FormationData.Shape.ARC), 5, Vector2.DOWN)
	assert_float(o[2].length()).is_equal_approx(0.0, 0.001)  # 가운데가 맨 뒤
	assert_float(o[0].y).is_greater(o[1].y)  # 양 날개가 영웅 쪽(아래)으로 더 나온다 (학익진)
	assert_float(o[4].y).is_greater(o[3].y)


func test_ring_keeps_radius() -> void:
	for p in FormationLayout.offsets(_data(FormationData.Shape.RING, 6), 6, Vector2.DOWN):
		assert_float(p.length()).is_equal_approx(300.0, 0.01)


func test_cycle_form_move_halt_aim_reload() -> void:
	var d := _data(FormationData.Shape.LINE)
	d.form_time = 0.2
	d.move_time = 1.0
	d.halt_time = 0.3
	d.reload_time = 0.5
	var c := FormationCycle.new(d)
	c.tick(0.1, false, false)
	assert_int(c.phase).is_equal(FormationCycle.Phase.FORM)
	c.tick(0.2, false, false)
	assert_int(c.phase).is_equal(FormationCycle.Phase.FORM)  # 다 모이기 전엔 안 움직인다
	c.tick(0.01, false, true)
	assert_int(c.phase).is_equal(FormationCycle.Phase.MOVE)
	c.tick(0.1, true)  # 멈출 거리에 닿음
	assert_int(c.phase).is_equal(FormationCycle.Phase.HALT)
	c.tick(0.31)
	assert_int(c.phase).is_equal(FormationCycle.Phase.AIM)
	assert_int(c.entered).is_equal(FormationCycle.Phase.AIM)
	c.tick(5.0)
	assert_int(c.phase).is_equal(FormationCycle.Phase.AIM)  # 바깥이 다 쐈다고 할 때까지
	c.aim_done()
	assert_int(c.phase).is_equal(FormationCycle.Phase.RELOAD)
	c.tick(0.51)
	assert_int(c.phase).is_equal(FormationCycle.Phase.MOVE)


## 네 무대 모두 원거리 대형이 1물결 1번 · 2물결 2번 · 4물결 3번 (3물결 중간 우두머리는 없음), 차례 자리는 물결 데이터대로.
func test_every_stage_queues_formations_1_2_0_3() -> void:
	for id in ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		var per := []
		for i in st.waves.waves.size():
			var r := WaveRunner.new(st.waves, 0.0)
			r._start(i)
			var at := []
			for k in r._queue.size():
				if r._queue[k] is FormationData:
					at.append(k)
			per.append(at.size())
			var after: PackedInt32Array = st.waves.waves[i].formation_after
			for k in at.size():  # 앞 대형만큼 밀린다, 차례 끝을 넘는 자리는 맨 끝
				assert_int(at[k]).override_failure_message("%s w%d" % [id, i + 1]).is_equal(mini(after[k], r._queue.size() - at.size()) + k)
		# 1물결 대형은 근접을 다 잡았거나 하나 남았을 때 (차례 맨 끝, when_left 1): 처음 보는 사람이 대형만 상대한다
		var w1 := st.waves.waves[0].formations[0]
		assert_int(w1.when_left).override_failure_message(id).is_equal(1)
		var r1 := WaveRunner.new(st.waves, 0.0)
		r1._start(0)
		assert_bool(r1._queue[-1] is FormationData).override_failure_message(id).is_true()
		assert_array(per.slice(0, 4)).override_failure_message(id).is_equal([1, 2, 0, 3])
		for n in per.slice(4):  # 한산 배 건너뛰기 5·6물결 (대장선 호위대 떼 · 떼+정예)에는 대형 없음
			assert_int(n).override_failure_message(id).is_equal(0)


func test_hansan_wave2_queues_gunner_lines() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var r := WaveRunner.new(st.waves, 0.0)
	r._start(1)
	var marks := r._queue.filter(func(x: Variant) -> bool: return x is FormationData)
	assert_int(marks.size()).is_equal(2)
	var f := marks[0] as FormationData
	assert_int(f.count).is_equal(8)
	assert_int(f.shape).is_equal(FormationData.Shape.LINE)
	assert_str(String(f.member.id)).is_equal(String((load("res://data/enemies/waegun_gunner.tres") as EnemyData).id))


func test_join_before_ready_still_holds_solo_aim() -> void:
	# 생성기 configure는 add_child 전에 join을 부른다 (attack은 _ready에서 생긴다): 그래도 혼자 겨누면 안 된다.
	var d := _data(FormationData.Shape.LINE)
	d.member = load("res://data/enemies/waegun_gunner.tres")
	var b := FormationBrain.new(d, null, Vector2.ZERO, Vector2.DOWN)
	var e: Enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	e.data = d.member
	b.join(e, 0)
	assert_object(e.attack).is_null()
	add_child(auto_free(e))
	e.set_physics_process(false)
	assert_object(e.attack).is_not_null()
	assert_bool(e.attack.start_check.is_valid()).is_true()
	assert_bool(bool(e.attack.start_check.call(Vector2.ZERO))).is_false()
	assert_str(b.why_not(e)).is_equal("")


func test_formation_waits_for_room_under_wave_cap() -> void:
	# 대형은 한꺼번에 count명이 나온다: 살아 있는 수 + count가 물결 동시 상한을 넘으면 꺼내지 않는다 (폰 끊김).
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var r := WaveRunner.new(st.waves, 0.0)
	r._start(1)
	var f := r._queue.filter(func(x: Variant) -> bool: return x is FormationData)[0] as FormationData
	r._queue = [f]
	var cap := r.wave_cap(st.waves.max_alive)
	r._stagger = 0.0
	assert_array(r.next_spawn(cap - f.count + 1, st.waves.max_alive)).is_empty()
	r._stagger = 0.0
	assert_array(r.next_spawn(cap - f.count, st.waves.max_alive)).contains_exactly([f])


func test_late_member_after_broken_fights_alone() -> void:
	# 대형이 깨진 뒤 늦게 나온 구성원은 대형에 묶이지 않는다 (혼자 겨누기를 막지 않음: 서서 공격 안 하던 것).
	var d := _data(FormationData.Shape.LINE, 2)
	d.member = load("res://data/enemies/waegun_gunner.tres")
	d.form_timeout = 0.0
	var b := FormationBrain.new(d, null, Vector2.ZERO, Vector2.DOWN)
	b.tick(0.1)  # 아무도 안 왔고 기다림이 지났다 → 깨짐
	assert_bool(b.is_over()).is_true()
	var e: Enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	e.data = d.member
	b.join(e, 1)
	add_child(auto_free(e))
	e.set_physics_process(false)
	assert_object(e.formation).is_null()
	assert_bool(e.attack.start_check.is_valid()).is_false()


func test_two_formations_do_not_volley_together() -> void:
	# 같은 물결에 대형 둘이 같이 있으면 겨눔 시작이 volley_gap초 이상 엇갈린다 (같은 순간 16발 없게).
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	var d := _data(FormationData.Shape.LINE, 2)
	var a := FormationBrain.new(d, sp, Vector2.ZERO, Vector2.DOWN)
	var b := FormationBrain.new(d, sp, Vector2(0, 600), Vector2.UP)
	sp.formations.append(a)
	sp.formations.append(b)
	assert_bool(b.volley_blocked()).is_false()
	a.aimed_at = EnemyAttack.now_sec()
	assert_bool(b.volley_blocked()).is_true()
	assert_bool(a.volley_blocked()).is_false()  # 자기 자신은 막지 않는다
	a.aimed_at = EnemyAttack.now_sec() - d.volley_gap - 0.01
	assert_bool(b.volley_blocked()).is_false()


func test_wave1_formation_waits_until_melee_nearly_gone() -> void:
	# when_left: 물결에 살아 있는 적이 그 수 이하일 때만 나온다. 대형이 차례에 남아 있는 동안 물결은 끝나지 않는다.
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var r := WaveRunner.new(st.waves, 0.0)
	r._start(0)
	var f := r._queue[-1] as FormationData
	r._queue = [f]
	r._stagger = 0.0
	assert_array(r.next_spawn(2, st.waves.max_alive)).is_empty()
	assert_int(r.tick(0.1, 0, false)).is_not_equal(WaveRunner.Event.CLEARED)  # 근접을 다 잡아도 대형이 나오기 전엔 안 끝남
	r._stagger = 0.0
	assert_array(r.next_spawn(1, st.waves.max_alive)).contains_exactly([f])


func test_formation_member_kill_xp_uses_formation_mult() -> void:
	# 대형 구성원 처치 점수 = 반올림(xp × 무대 배율 × FormationData.xp_mult) (대형이 여럿이라 경지가 너무 빨라지지 않게).
	var d := load("res://data/formations/hansan_gunner_line.tres") as FormationData
	var b := FormationBrain.new(d, null, Vector2.ZERO, Vector2.DOWN)
	var e: Enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	e.data = d.member
	add_child(auto_free(e))
	e.set_physics_process(false)
	var cfg := RunConfig.new()
	cfg.levels = load("res://data/runs/level_rules.tres")
	cfg.score = load("res://data/runs/score_table.tres")
	var p := RunProgress.new(cfg)
	var feed := ScoreFeed.new(p, load("res://data/runs/score_table.tres"))
	var alone := feed.kill(e, 1.53)
	b.join(e, 0)
	assert_int(feed.kill(e, 1.53)).is_equal(roundi(d.member.xp * 1.53 * d.xp_mult))
	assert_int(alone).is_equal(roundi(d.member.xp * 1.53))


## 네 무대 대형 모두 경험치 배율이 1보다 작되, 구성원 하나가 적어도 1점은 준다 (반올림으로 0이 되지 않게).
func test_every_formation_gives_some_but_less_xp() -> void:
	for id in ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		for w: WaveData in st.waves.waves:
			for f: FormationData in w.formations:
				assert_float(f.xp_mult).override_failure_message(id).is_less(1.0)
				assert_int(roundi(f.member.xp * st.waves.xp_mult * f.xp_mult)).override_failure_message(id).is_greater_equal(1)


func test_formation_member_moves_out_of_a_rock_without_rng() -> void:
	# 대형 구성원 자리가 바위 속이면 그 자리 가까이 빈 곳으로 (생성기 난수를 쓰지 않아 다른 적 등장 자리는 그대로).
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	var rock := Vector3(500, 0, 80)  # x, y, 반지름
	sp.blocked_check = func(p: Vector2, m: float) -> bool: return p.distance_to(Vector2(rock.x, rock.y)) < rock.z + m
	var before := sp.rng.state
	var q: Vector2 = FormationSpawn.free_point(sp, Vector2(500, 0))
	assert_bool(bool(sp.blocked_check.call(q, sp.spawn_clearance))).is_false()
	assert_float(q.distance_to(Vector2(500, 0))).is_less_equal(150.0)  # 자리 가까이 (모양 유지)
	assert_int(sp.rng.state).is_equal(before)
	assert_vector(FormationSpawn.free_point(sp, Vector2(0, 0))).is_equal(Vector2(0, 0))  # 빈 자리는 그대로


func test_member_with_every_spot_blocked_is_not_spawned_and_wave_can_end() -> void:
	# 둘레가 다 막힌 자리의 구성원은 내지 않는다: 예고·살아 있는 수에 안 남고, 다 빠지면 대형은 곧바로 끝 (물결이 멈추지 않게).
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	add_child(sp)
	var hero: Node2D = auto_free(Node2D.new())
	add_child(hero)
	sp.target = hero
	sp.blocked_check = func(_p: Vector2, _m: float) -> bool: return true
	assert_that(FormationSpawn.free_point(sp, Vector2(500, 0))).is_null()
	var d := _data(FormationData.Shape.RING, 3)
	d.member = load("res://data/enemies/waegun_gunner.tres")
	d.form_timeout = 99.0
	var b := FormationSpawn.spawn(sp, d)
	assert_int(sp._warnings).is_equal(0)
	assert_int(sp.alive_count()).is_equal(0)
	b.tick(0.016)
	assert_bool(b.is_over()).is_true()


func test_refill_leaves_room_for_the_next_formation() -> void:
	# 곧 나올 대형(차례 앞 셋 안) 몫을 상한에 남겨 둔다: 대형 차례가 오면 기다림 없이 바로 선다.
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var r := WaveRunner.new(st.waves, 0.0)
	r._start(1)
	var f: FormationData = r._queue.filter(func(x: Variant) -> bool: return x is FormationData and (x as FormationData).when_left < 0)[0]
	var soldier: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	r._queue = [soldier, soldier, f]
	var cap := r.wave_cap(st.waves.max_alive)
	r._stagger = 0.0
	assert_array(r.next_spawn(cap - f.count, st.waves.max_alive)).is_empty()  # 대형 몫을 남김
	r._stagger = 0.0
	assert_array(r.next_spawn(cap - f.count - 1, st.waves.max_alive)).contains_exactly([soldier])
	r._queue = [f]
	r._stagger = 0.0
	assert_array(r.next_spawn(cap - f.count, st.waves.max_alive)).contains_exactly([f])  # 자리가 남아 있어 바로
