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
