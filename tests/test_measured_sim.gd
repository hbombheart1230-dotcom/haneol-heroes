extends GdUnitTestSuite
## 실측 조정 균형 확인 (헤드리스 시뮬레이션): 순신이 제자리에 서 있고 왜군이 늘 같은 수로 살아 있게 보충한다.
## "가만히 있으면 진다, 탭 연타를 쓰면 더 낫다"를 실제 노드로 잰다. 결과는 로그(print)에 남긴다.
## 결정적으로 (통합 세션 지적, 실행마다 통과·실패가 바뀌던 문제):
##  - 한 물리 프레임 안에서 고정 틱(DT)으로 돈다 (move_and_slide가 물리 프레임 밖에서는 실제 프레임 delta를 썼다).
##  - 고정 틱(DT)만 쓴다: 기술 멈춤(SkillHitStop·GameTime)은 끄고 Engine.time_scale을 1로 고정
##    (move_and_slide가 쓰는 물리 delta가 시간 배율을 따라 바뀌던 것), 적 공격의 시계도 시뮬 시간으로 (EnemyAttack.clock).
##  - 전역 상태(동시 예고 수·근접 공격권)를 판마다 비운다.
##  - 한 판이 아니라 씨앗 여러 개의 평균으로, 여유 있는 기준으로 판정한다. 테스트끼리 결과를 나누지 않는다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const GUNNER := preload("res://data/enemies/waegun_gunner.tres")
const HEAVY := preload("res://data/enemies/waegun_heavy.tres")
const DT := 1.0 / 60.0
const LIMIT := 60.0
## 손 탭 간격(초): 사람이 빠르게 두드리는 정도 (초당 5번).
const TAP_GAP := 0.2
const SEEDS := [3, 7, 11, 19]

var _t: float = 0.0
var _spawned: int = 0
## 시뮬 전용 난수 (전역 난수는 다른 코드·도구가 함께 써서 실행마다 순서가 달라진다).
var _rng := RandomNumberGenerator.new()


func after_test() -> void:
	_reset_globals()
	EnemyAttack.clock = Callable()


func _reset_globals() -> void:
	EnemyAttack.active_windups = 0
	AttackTokens.clear()
	SkillHitStop.reset()
	GameTime.reset()
	Engine.time_scale = 1.0


## 옛 값 (2.5초 대기, 피해 20, 경직 공통 0.15, 대기 다시 세기 없음)으로 바꾼 사본.
func _old(d: EnemyData) -> EnemyData:
	var o := d.duplicate() as EnemyData
	o.attack = d.attack.duplicate() as EnemyAttackData
	if d == SOLDIER:
		o.attack.cooldown = 2.5
		o.attack.damage = 20
	else:
		o.attack.cooldown = 2.2
	o.stagger_time = -1.0
	o.hit_resets_attack = false
	return o


func _enemy(d: EnemyData, target: Player, at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = d
	e.target = target
	_spawned += 1
	e.ai_seed = _spawned  # 인스턴스 id 대신 (실행마다 같은 버릇)
	add_child(e)
	e.set_physics_process(false)
	e.global_position = at
	return e


func _place(d: EnemyData, k: int, n: int) -> Vector2:
	var r := 380.0 if d.attack.kind == EnemyAttackData.Kind.SHOOT else 220.0
	return Vector2.from_angle(TAU * k / float(n) + _rng.randf_range(-0.3, 0.3)) * r


## 한 판: kinds 순서대로 늘 살아 있게 (죽으면 같은 종류로 보충). [버틴 시간, 처치 수, 받은 피해] — 판이 끝나면 다 지운다.
func _run(kinds: Array, tap: bool, s: int, chase: bool = false) -> Array:
	_reset_globals()
	# 물리 프레임 안에서 돌린다: move_and_slide는 물리 프레임 밖에서 부르면 실제 화면 프레임 delta를 써서
	# 기계·부하마다 이동량이 달라졌다 (실행마다 결과가 바뀌던 원인). 한 물리 프레임 안에서 고정 DT로 끝까지 돈다.
	await get_tree().physics_frame
	seed(s)
	_rng.seed = s
	_t = 0.0
	_spawned = 0
	EnemyAttack.clock = func() -> float: return _t
	var player := Player.new()
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = YI
	add_child(player)
	player.set_physics_process(false)
	var atk := AutoAttack.new()
	atk.name = "AutoAttack"
	atk.player = player
	atk.data = YI.attack
	atk.projectile_scene = PROJECTILE_SCENE
	atk.projectile_parent = self
	player.add_child(atk)
	atk.set_physics_process(false)
	var enemies: Array = []
	var caster := SkillCaster.new()
	caster.player = player
	caster.kit = YI.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false  # 실제 시간으로 풀리는 멈춤은 시뮬레이션에서 끈다
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)
	for k in kinds.size():
		enemies.append(_enemy(kinds[k], player, _place(kinds[k], k, kinds.size())))
	var kills := 0
	var tap_t := 0.0
	while _t < LIMIT and not player.is_dead():
		_t += DT
		Engine.time_scale = 1.0
		if chase:  # 쫓아가기: 걸어서 다가가고, 멀면 대시 (근접만인 영웅이 조총병에 닿는 방법)
			var near: Enemy = null
			for e0 in enemies:
				if is_instance_valid(e0) and (near == null or player.global_position.distance_to(e0.global_position) < player.global_position.distance_to(near.global_position)):
					near = e0
			if near:
				var to := near.global_position - player.global_position
				player.move_input = to.normalized() if to.length() > 90.0 else Vector2.ZERO
				if to.length() > 220.0:
					player.request_dash(to.normalized())
		player._physics_process(DT)
		caster.tick(DT, _t)
		tap_t -= DT
		if tap and tap_t <= 0.0:
			tap_t = TAP_GAP
			caster.combo_tap()
		atk.tick(DT, enemies)
		for i in enemies.size():
			var e: Enemy = enemies[i]
			if not is_instance_valid(e) or e.health.is_dead():
				kills += 1
				if is_instance_valid(e):
					e.free()
				enemies[i] = _enemy(kinds[i], player, _place(kinds[i], i, kinds.size()))
				continue
			e._physics_process(DT)
	var out := [_t, kills, player.health.max - player.health.current]
	for e in enemies:
		if is_instance_valid(e):
			e.free()
	for c in get_children():
		if c is Projectile or c is EnemyArrow:
			c.free()
	caster.free()
	player.free()
	_reset_globals()
	return out


## 씨앗 여러 개 평균: [평균 버틴 시간, 평균 초당 처치, 평균 피해당 처치, 다 졌는지].
func _avg(kinds: Array, tap: bool, label: String) -> Array:
	var t := 0.0
	var kps := 0.0
	var kpd := 0.0
	var all_died := true
	for s in SEEDS:
		var r: Array = await _run(kinds, tap, s)
		t += r[0]
		kps += r[1] / maxf(r[0], 1.0)
		kpd += r[1] / maxf(r[2], 1.0)
		all_died = all_died and r[0] < LIMIT
	var n := float(SEEDS.size())
	print("[sim] %s: survived %.1fs avg, %.2f kills/s, %.3f kills per damage (%d seeds)" % [label, t / n, kps / n, kpd / n, SEEDS.size()])
	return [t / n, kps / n, kpd / n, all_died]


## 같은 씨앗이면 같은 결과 (결정적).
func test_sim_is_deterministic() -> void:
	var a: Array = await _run([SOLDIER, SOLDIER, GUNNER], true, 5)
	var b: Array = await _run([SOLDIER, SOLDIER, GUNNER], true, 5)
	assert_array(a).is_equal(b)


## 물결 1 (상한 3: 병사 둘 + 조총): 가만히 있으면 지고, 탭 연타가 더 빨리·덜 맞고 잡는다.
func test_wave1_standing_loses_and_tapping_does_better() -> void:
	var idle : Array = await _avg([SOLDIER, SOLDIER, GUNNER], false, "after, wave 1 standing")
	var tap : Array = await _avg([SOLDIER, SOLDIER, GUNNER], true, "after, wave 1 tapping")
	assert_bool(idle[3]).override_failure_message("standing still should lose within %ds" % LIMIT).is_true()
	assert_float(tap[1]).is_greater(idle[1] * 1.1)  # 초당 처치 10% 이상 많다
	assert_float(tap[2]).is_greater(idle[2] * 1.1)  # 피해당 처치 10% 이상 많다


## 물결 3 (상한 5: 병사 셋 + 조총 + 중장): 가만히·회피 없이 탭만 해도 버틸 수 없다 (회피·기술이 필요).
func test_wave3_needs_more_than_tapping() -> void:
	var kinds := [SOLDIER, SOLDIER, GUNNER, SOLDIER, HEAVY]
	var idle : Array = await _avg(kinds, false, "after, wave 3 standing")
	var tap : Array = await _avg(kinds, true, "after, wave 3 tapping (no dodge)")
	assert_bool(idle[3]).is_true()
	assert_bool(tap[3]).is_true()


## 기록용: 옛 값 (같은 씨앗).
func test_before_values_for_the_record() -> void:
	var idle : Array = await _avg([_old(SOLDIER), _old(SOLDIER), _old(GUNNER)], false, "before, standing")
	var tap : Array = await _avg([_old(SOLDIER), _old(SOLDIER), _old(GUNNER)], true, "before, tapping")
	assert_bool(idle[3]).is_true()
	assert_float(tap[0]).is_greater(0.0)


## 조총병만 남았을 때 (근접만인 순신): 다가가고 대시하며 탭하면 잡을 수 있다 (원거리 평타 없이).
func test_lone_gunner_is_solvable_by_chasing() -> void:
	var t := 0.0
	var kps := 0.0
	var hurt := 0.0
	for s in SEEDS:
		var r: Array = await _run([GUNNER], true, s, true)
		t += r[0]
		kps += r[1] / maxf(r[0], 1.0)
		hurt += r[2] / maxf(r[1], 1.0)
	var n := float(SEEDS.size())
	print("[sim] lone gunner, chase + tap: %.2f kills/s, %.1f damage per kill (%d seeds)" % [kps / n, hurt / n, SEEDS.size()])
	assert_float(kps / n).is_greater(0.15)  # 조총병 하나를 약 6초 안에
	assert_float(hurt / n).is_less(30.0)  # 하나 잡는 데 체력 30% 미만
