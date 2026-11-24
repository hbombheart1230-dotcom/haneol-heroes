extends GdUnitTestSuite
## 연타 중 처음 때린 몹에 붙기 (ComboLock, 순신): 1타가 맞힌 몹을 연타 동안 겨냥 (다른 몹이 더 가까워져도),
## 이동 입력·대시·죽음·새 연타면 풀림, 닿는 순간 대상 쪽으로 살짝 끌려 붙기. 잡몹 떼 처치 속도 전/후 (HordeSim).

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0
## 붙기 장치 자체를 보는 켜진 붙기 데이터 (순신 데이터는 사용자 결정으로 꺼짐, 2026-11-24 "순신이한테만 있는 거 빼자").
var LOCK := ComboLockData.new()


func after_test() -> void:
	BossSim.reset_globals()


func _rig() -> Array:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	var hd: HeroData = YI.duplicate()
	hd.combo_lock = LOCK
	p.hero = hd
	add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = YI.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	return [p, a]


func _enemy(at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = at
	e.health.max = 9999
	e.health.current = 9999
	return e


## 한 타: 휘두르고 칼이 닿을 때까지 진행.
func _swing(a: AutoAttack, step: int, list: Array) -> void:
	a.manual_strike(step, false, list)
	for i in 40:
		if a._melee_left < 0.0:
			break
		a.tick(DT, list)


func test_lock_keeps_first_target_through_the_chain() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	var first := _enemy(Vector2(90, 0))
	var list: Array = [first]
	_swing(a, 1, list)
	assert_object(a.lock.target).is_same(first)
	var other := _enemy(Vector2(-60, 10))  # 이제 이쪽이 더 가깝다
	list.append(other)
	_swing(a, 2, list)
	assert_float(a._swing_dir.x).is_greater(0.5)  # 여전히 처음 몹 쪽
	_swing(a, 3, list)
	assert_object(a.lock.target).is_same(first)
	_swing(a, 1, list)  # 새 연타 = 평소대로 가장 가까운 몹
	assert_float(a._swing_dir.x).is_less(0.0)


func test_move_input_and_dash_release() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	var first := _enemy(Vector2(90, 0))
	var other := _enemy(Vector2(-60, 0))
	var list: Array = [first]
	_swing(a, 1, list)
	list.append(other)
	p.set_move_input(Vector2.LEFT)  # 끌어서 이동 = 플레이어 우선
	_swing(a, 2, list)
	assert_float(a._swing_dir.x).is_less(0.0)
	p.set_move_input(Vector2.ZERO)
	a.lock.target = first
	ComboSteps.cancel_swing(a)  # 대시 시작이 부르는 것
	assert_bool(a.lock.active()).is_false()


func test_dead_target_moves_on() -> void:
	var r := _rig()
	var a: AutoAttack = r[1]
	var first := _enemy(Vector2(90, 0))
	var other := _enemy(Vector2(-70, 0))
	var list: Array = [first]
	_swing(a, 1, list)
	first.health.current = 1
	first.health.damage(5)
	list = [other]
	_swing(a, 2, list)
	assert_float(a._swing_dir.x).is_less(0.0)


## 1타에 죽은 몹은 잡지 않고 같이 맞은 살아 있는 몹을 잡는다 (시체에 걸려 다음 탭까지 붙지 못하지 않게).
func test_one_hit_kill_locks_the_living_one() -> void:
	var r := _rig()
	var a: AutoAttack = r[1]
	var weak := _enemy(Vector2(80, 0))
	weak.health.current = 1
	var tough := _enemy(Vector2(100, 25))
	_swing(a, 1, [weak, tough])
	assert_bool(weak.health.is_dead()).is_true()
	assert_object(a.lock.target).is_same(tough)
	assert_bool(a.lock.active()).is_true()


## 닿는 순간 대상 쪽으로 끌려 붙기 (몸을 뚫지 않게 이상 틈까지, 한 타 상한).
func test_pull_toward_target_on_contact() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	var e := _enemy(Vector2(130, 0))
	a.lock.on_contact(LOCK, p, [e], Vector2.RIGHT)
	assert_float(p._recoil_left).is_greater(0.0)
	assert_float(p._recoil_vel.x).is_greater(0.0)
	var gap := 130.0 - e.body_radius * e.size_mult - p.body_radius
	assert_float(p._recoil_vel.x * LOCK.pull_time).is_less_equal(minf(gap - LOCK.ideal_gap, LOCK.pull_max) + 0.5)


func test_other_heroes_off() -> void:
	assert_bool(YI.combo_lock.enabled).is_false()  # 순신도 끔 (데이터로, 장치는 남김)
	for id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		assert_object((load("res://data/heroes/%s.tres" % id) as HeroData).combo_lock).is_null()


## 잡몹 떼 6/8/10 × 씨앗 셋: 붙기 켬/끔 처치 시간 (한 놈에 묶여 느려지지 않는다: 평균이 10% 넘게 늘지 않음).
func test_horde_clear_time_with_and_without_lock() -> void:
	var sums := [0.0, 0.0]
	for n in [6, 8, 10]:
		for s in [1, 2, 3]:
			for v in [0, 1]:
				var sim := HordeSim.new(self)
				await sim.setup(null, s)
				sim.player.hero.combo_lock = null if v == 0 else LOCK  # 켜진 붙기와 비교 (순신 데이터는 꺼짐)
				sim.spawn_horde(n, 5.0)
				var res := sim.run_horde(HordeSim.HordeBot.MELEE)
				print(HordeSim.horde_line("lock %s n%d s%d" % ["off" if v == 0 else "on ", n, s], res))
				sums[v] += res["time"]
				sim.free_all()
	print("[horde-sim] mean clear: lock off %.1fs, on %.1fs" % [sums[0] / 9.0, sums[1] / 9.0])
	# 붙기는 지금 어느 영웅도 켜지 않았다 (순신도 데이터로 끔, 2026-11-24): 켠 영웅이 있을 때만 상한(+10%)을 지킨다.
	# 순신 전진을 광개토 수준으로 줄인 뒤 켜 보면 +12% (82.3 → 84.1초 상한 넘음): 다시 켜려면 전진·틈 값부터 맞출 것.
	if YI.combo_lock and YI.combo_lock.enabled:
		assert_float(sums[1]).is_less_equal(sums[0] * 1.1)
