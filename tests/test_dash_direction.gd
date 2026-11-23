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
	for id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		assert_object((load("res://data/heroes/%s.tres" % id) as HeroData).dash_dir).is_null()


## 잡몹 떼 6/8/10 × 씨앗 셋: 돌진만 쓰는 봇이 평타 봇보다 유리하지 않다 (잡는 시간이 더 길거나 받은 피해가 더 크다).
func test_dash_only_bot_is_not_better_than_melee() -> void:
	var rows: Array = []
	var dash_better := 0
	for n in [6, 8, 10]:
		for s in [1, 2, 3]:
			var r: Array = []
			for bot in [HordeSim.HordeBot.MELEE, HordeSim.HordeBot.DASH]:
				var sim := HordeSim.new(self)
				await sim.setup(null, s)
				sim.spawn_horde(n, 5.0)
				var res := sim.run_horde(bot)
				print(HordeSim.horde_line("%s n%d s%d" % ["melee" if bot == HordeSim.HordeBot.MELEE else "dash ", n, s], res))
				r.append(res)
				sim.free_all()
			rows.append([n, s, r[0], r[1]])
			if r[1]["cleared"] and r[1]["time"] < r[0]["time"] and r[1]["damage"] <= r[0]["damage"]:
				dash_better += 1
	assert_int(dash_better).is_equal(0)


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
