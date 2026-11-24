extends GdUnitTestSuite
## 밀림 재설계 (사용자: "3타에 크게 밀리면 4타 스킬은 허공에 날릴거야"): 1·2타 거의 안 밀림, 3타 넘어짐,
## 큰 기술(넷째 탭 마무리·반격)과 사임당 3타 원 붓질은 정해진 곡선으로 크게 날린다 (EnemyLaunch).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const ELITE := preload("res://data/enemies/waegun_elite.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0


## 곡선: 다 합치면 정해진 거리, 처음 hold 동안은 거의 제자리, hold + time 뒤에 멈춘다.
func test_launch_curve_distance_and_shape() -> void:
	var l := EnemyLaunch.new()
	l.start(Vector2.RIGHT, 110.0, 0.05, 0.3)
	var x := 0.0
	var t := 0.0
	var at_hold := 0.0
	while l.active():
		x += l.tick(DT).x * DT
		t += DT
		if t <= 0.05 + 0.001:
			at_hold = x
	assert_float(x).is_equal_approx(110.0, 2.0)
	assert_float(at_hold).is_less(110.0 * 0.06)  # 맞고 잠깐은 거의 제자리
	assert_float(t).is_between(0.33, 0.4)  # 닿고 약 0.35~0.4초에 선다


func test_launch_scales_with_enemy_weight_and_outward() -> void:
	var a: Enemy = ENEMY_SCENE.instantiate()
	a.data = SOLDIER
	add_child(auto_free(a))
	a.global_position = Vector2(60, 0)
	ComboSteps.push_out(a, Vector2.ZERO, 110.0, 0.0)
	assert_bool(a.launch.active()).is_true()
	assert_float(a.launch._dist).is_equal_approx(110.0 * SOLDIER.knockback_scale, 0.01)
	assert_float(a.launch._dir.x).is_greater(0.9)  # 바깥으로
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = ELITE
	add_child(auto_free(e))
	e.global_position = Vector2(-60, 0)
	ComboSteps.push_out(e, Vector2.ZERO, 110.0, 0.0)
	assert_float(e.launch._dist).is_less(30.0)  # 정예는 거의 안 날아간다 (knockback_scale)


## 넷째 탭 마무리 = 크게, 평타 1·2타 = 작게: 영웅 데이터.
func test_hero_push_table() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	assert_float((yi.kit.tap as HaeryongSkill).launch_px).is_between(100.0, 130.0)
	assert_float((yi.kit.counter as CounterSlashSkill).launch_px).is_between(100.0, 130.0)
	var gw: HeroData = load("res://data/heroes/gwanggaeto.tres")
	assert_float((gw.kit.tap as QuakeSkill).launch_px).is_between(100.0, 130.0)
	var sj: HeroData = load("res://data/heroes/sejong.tres")
	assert_float((sj.kit.tap as JeongeumSkill).launch_px).is_between(80.0, 130.0)
	var sa: HeroData = load("res://data/heroes/shin_saimdang.tres")
	assert_float(sa.attack.heavy_launch_px).is_between(100.0, 130.0)
	var small := yi.attack.melee_knockback * ComboSteps.at(yi.attack.step_knockback_mults, 1, 1.0) / 8.0
	assert_float(small).is_less(20.0)


## 사임당 3타(원 붓질)는 넉백 대신 크게 날린다.
func test_saimdang_third_flick_launches() -> void:
	var sa: HeroData = load("res://data/heroes/shin_saimdang.tres")
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.global_position = Vector2(0, 150)
	ComboSteps.push(e, Vector2.ZERO, 200.0, true, sa.attack)
	assert_bool(e.launch.active()).is_true()
	assert_float(e.knockback.length()).is_equal(0.0)
	var f: Enemy = ENEMY_SCENE.instantiate()
	f.data = SOLDIER
	add_child(auto_free(f))
	ComboSteps.push(f, Vector2(-10, 0), 200.0, false, sa.attack)  # 1·2타는 넉백
	assert_bool(f.launch.active()).is_false()
	assert_float(f.knockback.length()).is_greater(0.0)


## 검증 지적 1: 기절·넘어짐 중에도 바로 날아간다 (광개토 지진·정복은 밀고 기절시킨다).
func test_launch_moves_while_stunned() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(60, 0)
	ComboSteps.push_out(e, Vector2.ZERO, 120.0, 0.0)
	e.stun(1.2)
	await get_tree().physics_frame
	for i in 30:  # 0.5초 (기절은 아직)
		e._physics_process(DT)
	assert_float(e._stun_left).is_greater(0.0)
	assert_float(e.global_position.x - 60.0).is_greater(120.0 * SOLDIER.knockback_scale * 0.8)


## 검증 지적 2: 보스·갑옷 정예는 넉백처럼 날아가지 않고 (poise), 돌진도 멈추지 않는다.
func test_boss_and_armored_not_launched() -> void:
	for d in [load("res://data/enemies/waegun_commander.tres"), ELITE]:
		var e: Enemy = ENEMY_SCENE.instantiate()
		e.data = d
		add_child(auto_free(e))
		e.global_position = Vector2(60, 0)
		if e.poise == null or e.poise.knockback_mult() > 0.0:
			continue
		ComboSteps.push_out(e, Vector2.ZERO, 120.0, 0.0)
		assert_bool(e.launch.active()).is_false()


## 검증 지적 3: 대시가 휘두름 느려짐을 지운다.
func test_dash_clears_swing_slow() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = load("res://data/heroes/yi_sun_sin.tres")
	add_child(p)
	p.slow_for(0.2, 0.35)
	assert_bool(p.request_dash(Vector2.RIGHT)).is_true()
	assert_float(p._swing_left).is_equal(0.0)
