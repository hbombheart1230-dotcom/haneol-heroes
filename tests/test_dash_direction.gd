extends GdUnitTestSuite
## 대시를 방향으로 나누기 (사용자: "한번 구현하고 보자", 순신만): 적 쪽 = 돌진 타격, 반대쪽 = 뒤로 빠지기, 옆·적 없음 = 지금 대시.
## 걱정: "대시 중 타격이 무적일까 봐. 그걸로 다 쓸면 난이도가 너무 낮아진다" → 잡몹 떼 시뮬 (돌진만 vs 평타).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	BossSim.reset_globals()


func _player() -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = YI
	add_child(p)
	p.set_physics_process(false)
	return p


func _enemy(at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = at
	return e


func test_classify_by_angle() -> void:
	var d := YI.dash_dir
	assert_int(DashDirection.classify(d, Vector2.RIGHT, Vector2(200, 0))).is_equal(DashDirection.Kind.CHARGE)
	assert_int(DashDirection.classify(d, Vector2(1, 0.5).normalized(), Vector2(200, 0))).is_equal(DashDirection.Kind.CHARGE)
	assert_int(DashDirection.classify(d, Vector2.LEFT, Vector2(200, 0))).is_equal(DashDirection.Kind.BACK)
	assert_int(DashDirection.classify(d, Vector2.UP, Vector2(200, 0))).is_equal(DashDirection.Kind.SIDE)
	assert_int(DashDirection.classify(d, Vector2.RIGHT, Vector2.ZERO)).is_equal(DashDirection.Kind.SIDE)  # 적 없음


## 돌진: 지나간 몹에 1타급 이하 피해, 몹당 한 번.
func test_charge_strikes_each_enemy_once_below_first_hit() -> void:
	var p := _player()
	var a := _enemy(Vector2(120, 0))
	var b := _enemy(Vector2(200, 10))
	var hp := a.health.current
	await get_tree().physics_frame  # 한 물리 프레임 안에서 고정 틱으로 (move_and_slide가 실제 delta를 쓰지 않게)
	assert_bool(p.request_dash(Vector2.RIGHT)).is_true()
	assert_int(p.dash_kind).is_equal(DashDirection.Kind.CHARGE)
	for i in 12:
		p._physics_process(DT)
	var dmg := hp - a.health.current
	assert_int(dmg).is_greater(0)
	assert_int(dmg).is_less_equal(YI.attack.melee_damage)
	assert_int(b.health.current).is_less(hp)
	assert_int(p.dash_struck.size()).is_equal(2)


## 뒤로 빠지기: 타격 없음, 적을 본 채로.
func test_backstep_faces_enemy_without_hitting() -> void:
	var p := _player()
	var a := _enemy(Vector2(60, 0))
	var hp := a.health.current
	await get_tree().physics_frame
	p.request_dash(Vector2.LEFT)
	assert_int(p.dash_kind).is_equal(DashDirection.Kind.BACK)
	assert_bool(p.dash_strikes).is_false()
	assert_float(p.facing.x).is_greater(0.9)
	for i in 12:
		p._physics_process(DT)
	assert_int(a.health.current).is_equal(hp)


## 연속 대시에서는 첫 대시만 타격.
func test_chained_dash_does_not_strike() -> void:
	var p := _player()
	_enemy(Vector2(500, 0))
	p.request_dash(Vector2.RIGHT)
	assert_bool(p.dash_strikes).is_false()  # 420px 밖: 옆 대시와 같다
	_enemy(Vector2(150, 0))
	p.request_dash(Vector2.RIGHT)  # 대시 중 다시 = 연속
	assert_bool(p.dash_strikes).is_false()
	for i in 50:  # 대시 0.12초 + chain_gap 0.6초 넘게
		p.compute_velocity(DT)
	assert_bool(p.request_dash(Vector2.RIGHT)).is_true()
	assert_bool(p.dash_strikes).is_true()  # chain_gap 지난 새 대시


## 개발용 되돌리기 값 하나로 끔. 다른 영웅은 데이터 없음 (세종 포함: 회피 동작만).
func test_toggle_and_other_heroes() -> void:
	var p := _player()
	_enemy(Vector2(150, 0))
	var d: DashDirData = YI.dash_dir.duplicate()
	d.strike_enabled = false
	var h: HeroData = YI.duplicate()
	h.dash_dir = d
	p.hero = h
	p.request_dash(Vector2.RIGHT)
	assert_int(p.dash_kind).is_equal(DashDirection.Kind.CHARGE)
	assert_bool(p.dash_strikes).is_false()



## 네 영웅 모두 같은 규칙 (사용자 승인 2026-11-24): 충전 하나 더 + 끝 경직. 성격은 데이터로: 광개토는 묵직하게 밀쳐냄, 원거리(세종·사임당)는 약한 피해 + 다른 효과.
func test_every_hero_strikes_with_the_same_cost() -> void:
	var yi_mult := YI.dash_dir.strike_damage_mult
	for id in ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]:
		var d := (load("res://data/heroes/%s.tres" % id) as HeroData).dash_dir
		assert_object(d).override_failure_message(id).is_not_null()
		assert_bool(d.strike_enabled).override_failure_message(id).is_true()
		assert_int(d.strike_extra_charge).override_failure_message(id).is_equal(1)
		assert_float(d.strike_end_lag).override_failure_message(id).is_greater(0.0)
	var gw := (load("res://data/heroes/gwanggaeto.tres") as HeroData).dash_dir
	assert_float(gw.strike_push).is_greater(0.0)
	for id in ["sejong", "shin_saimdang"]:
		var d := (load("res://data/heroes/%s.tres" % id) as HeroData).dash_dir
		assert_float(d.strike_damage_mult).override_failure_message(id).is_less(yi_mult)
		assert_bool(d.strike_push > 0.0 or d.strike_slow_time > 0.0).override_failure_message(id).is_true()


## 밀쳐내기·느리게: 돌진 타격이 맞힌 몹에 데이터 값대로.
func test_strike_push_and_slow() -> void:
	var p := _player()
	var e := _enemy(Vector2(40, 0))
	var d: DashDirData = YI.dash_dir.duplicate()
	d.strike_push = 300.0
	d.strike_slow = 0.5
	d.strike_slow_time = 1.0
	var h: HeroData = YI.duplicate()
	h.dash_dir = d
	p.hero = h
	p.request_dash(Vector2.RIGHT)
	assert_bool(p.dash_strikes).is_true()
	p.velocity = Vector2.RIGHT * 800.0
	DashDirection.tick(p, [e], DT)
	assert_bool(p.dash_struck.has(e.get_instance_id())).is_true()
	assert_float(e.knockback.x).is_greater(0.0)
	assert_float(e.speed_scale()).is_less(0.6)


## 잡몹 떼 6/8/10 × 씨앗 셋, 네 영웅: 돌진만 쓰는 봇이 평타 봇보다 유리하지 않다.
## 영웅마다 아홉 판 합과 무리 크기(6·8·10)별 씨앗 셋 합 모두 돌진만 쓰는 쪽이 짧으면 안 되고 (진짜 유리함),
## 한 판은 25% 넘게 빨라야 "유리"로 본다 (판 하나의 흔들림).
## 25%인 까닭 (2026-11-25, int/next-k): 순신 n10 s1 돌진만 10.6초 < 평타 12.9초 (18%, 피해 둘 다 0)로 실패했다.
## n10을 씨앗 1~20으로 재면 돌진만이 빠른 판이 3/20 (18% / 7% / 9%)이고 합은 평타 205.4초 < 돌진만 248.5초라,
## 평타가 운 나쁘게 흩어진 무리를 만난 판이지 돌진만이 나은 전략이 된 것이 아니다.
const ONE_BOARD_MARGIN := 0.75


func test_dash_only_bot_is_not_better_than_melee() -> void:
	var better: Array = []
	for id in ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]:
		var sums := [0.0, 0.0]
		for n in [6, 8, 10]:
			var size_sums := [0.0, 0.0]  # 무리 크기별 씨앗 셋 합 (독립 검토 2026-11-25: 영웅 × 크기마다 평타가 빨라야)
			for s in [1, 2, 3]:
				var r: Array = []
				for bot in [HordeSim.HordeBot.MELEE, HordeSim.HordeBot.DASH]:
					var sim := HordeSim.new(self)
					sim.hero_path = "res://data/heroes/%s.tres" % id
					await sim.setup(null, s)
					sim.spawn_horde(n, 5.0)
					var res := sim.run_horde(bot)
					print(HordeSim.horde_line("%s %s n%d s%d" % [id, "melee" if bot == HordeSim.HordeBot.MELEE else "dash ", n, s], res))
					r.append(res)
					sim.free_all()
				sums[0] += float(r[0]["time"])
				sums[1] += float(r[1]["time"])
				size_sums[0] += float(r[0]["time"])
				size_sums[1] += float(r[1]["time"])
				if r[1]["cleared"] and r[1]["time"] < r[0]["time"] * ONE_BOARD_MARGIN and r[1]["damage"] <= r[0]["damage"]:
					better.append("%s n%d s%d" % [id, n, s])
			print("[horde-sim] %s n%d sum: melee %.1fs, dash-only %.1fs" % [id, n, size_sums[0], size_sums[1]])
			if size_sums[1] < size_sums[0]:
				better.append("%s n%d sum (melee %.1f, dash %.1f)" % [id, n, size_sums[0], size_sums[1]])
		print("[horde-sim] %s sum: melee %.1fs, dash-only %.1fs" % [id, sums[0], sums[1]])
		if sums[1] < sums[0]:
			better.append("%s sum" % id)
	assert_array(better).is_empty()


## 예고 범위 안에서 시작한 대시 = 회피: 적 쪽이어도 돌진 타격·대가 없음 (메인 결정: 회피를 방해하지 않게).
func test_escape_dash_from_telegraph_does_not_strike() -> void:
	var p := _player()
	var e := _enemy(Vector2(60, 0))
	e.attack.state = EnemyAttack.State.WINDUP
	e.attack.aim_origin = e.global_position
	e.attack.target_point = p.global_position
	e.attack.aim_dir = Vector2.LEFT
	assert_bool(ComboSteps.in_windup([e], p.global_position)).is_true()
	p.request_dash(Vector2.RIGHT)
	assert_int(p.dash_kind).is_equal(DashDirection.Kind.CHARGE)
	assert_bool(p.dash_strikes).is_false()
	e.attack.state = EnemyAttack.State.READY
