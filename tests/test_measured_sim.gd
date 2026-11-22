extends GdUnitTestSuite
## 실측 조정 균형 확인 (헤드리스 시뮬레이션): 순신이 제자리에 서 있고 왜군 셋(병사 둘 + 조총 하나)이 늘 살아 있게
## 보충한다 (물결 1 상한 3). "가만히 있으면 진다, 탭 연타를 쓰면 더 버틴다"를 실제 노드로 잰다.
## 결과는 로그(print)로 남긴다: 버틴 시간·처치 수·받은 피해.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const GUNNER := preload("res://data/enemies/waegun_gunner.tres")
const DT := 1.0 / 60.0
const LIMIT := 60.0
## 손 탭 간격(초): 사람이 빠르게 두드리는 정도 (초당 5번).
const TAP_GAP := 0.2
## 결과 기록 (테스트 순서대로 채운다).
static var results := {}

var player: Player
var atk: AutoAttack
var caster: SkillCaster
var enemies: Array = []


func before_test() -> void:
	EnemyAttack.active_windups = 0
	enemies = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = YI
	add_child(player)
	player.global_position = Vector2.ZERO
	player.set_physics_process(false)
	atk = auto_free(AutoAttack.new())
	atk.name = "AutoAttack"
	atk.player = player
	atk.data = YI.attack
	atk.projectile_scene = PROJECTILE_SCENE
	atk.projectile_parent = self
	player.add_child(atk)
	atk.set_physics_process(false)
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = YI.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()


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


func _spawn(d: EnemyData, k: int) -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = d
	e.target = player
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2.from_angle(TAU * k / 5.0 + 0.3) * (380.0 if d.attack.kind == EnemyAttackData.Kind.SHOOT else 200.0)
	enemies.append(e)


## seconds초 동안 (또는 죽을 때까지): 늘 병사 둘 + 조총 하나. tap = 손 연타(마무리 포함). [버틴 시간, 처치 수, 받은 피해]
func _run(soldier: EnemyData, gunner: EnemyData, tap: bool) -> Array:
	return _run_kinds([soldier, soldier, gunner], tap)


## kinds 순서대로 늘 살아 있게 (죽으면 같은 종류로 보충).
func _run_kinds(kinds: Array, tap: bool) -> Array:
	var kills := 0
	var t := 0.0
	var tap_t := 0.0
	for k in kinds.size():
		_spawn(kinds[k], k)
	while t < LIMIT and not player.is_dead():
		t += DT
		player._physics_process(DT)
		caster.tick(DT, t)
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
					e.queue_free()
				var e2: Enemy = ENEMY_SCENE.instantiate()  # 한 마리 죽으면 한 마리 (하데스식 보충)
				e2.data = kinds[i]
				e2.target = player
				add_child(auto_free(e2))
				e2.set_physics_process(false)
				e2.global_position = Vector2.from_angle(randf() * TAU) * (380.0 if (kinds[i] as EnemyData).attack.kind == EnemyAttackData.Kind.SHOOT else 260.0)
				enemies[i] = e2
				continue
			e._physics_process(DT)
	return [t, kills, player.health.max - player.health.current]


func test_a_after_standing() -> void:
	seed(7)
	results["after_idle"] = _run(SOLDIER, GUNNER, false)
	print("[sim] after, standing (auto attack only): survived %.1fs, kills %d, damage %d" % results["after_idle"])
	assert_bool(player.is_dead()).override_failure_message("standing still should lose within %ds" % LIMIT).is_true()


func test_b_after_tapping() -> void:
	seed(7)
	results["after_tap"] = _run(SOLDIER, GUNNER, true)
	print("[sim] after, tapping (combo + finisher): survived %.1fs, kills %d, damage %d" % results["after_tap"])
	var idle: Array = results["after_idle"]
	var tap: Array = results["after_tap"]
	assert_float(float(tap[1]) / tap[0]).is_greater(float(idle[1]) / idle[0])  # 더 빨리 잡는다
	assert_float(float(tap[1]) / maxf(tap[2], 1.0)).is_greater(float(idle[1]) / maxf(idle[2], 1.0))  # 피해당 처치가 많다


func test_c_before_standing() -> void:
	seed(7)
	results["before_idle"] = _run(_old(SOLDIER), _old(GUNNER), false)
	print("[sim] before, standing: survived %.1fs, kills %d, damage %d" % results["before_idle"])
	assert_float(results["before_idle"][0]).is_greater(0.0)


func test_d_before_tapping() -> void:
	seed(7)
	results["before_tap"] = _run(_old(SOLDIER), _old(GUNNER), true)
	print("[sim] before, tapping: survived %.1fs, kills %d, damage %d" % results["before_tap"])
	assert_float(results["before_tap"][0]).is_greater(0.0)


## 물결 3 구성 (상한 5: 병사 셋 + 조총 + 중장)을 늘 채운 채: 가만히 있으면 금방 진다.
func test_e_after_wave3_standing() -> void:
	seed(7)
	var heavy: EnemyData = load("res://data/enemies/waegun_heavy.tres")
	var r := _run_kinds([SOLDIER, SOLDIER, GUNNER, SOLDIER, heavy], false)
	print("[sim] after, wave 3 standing: survived %.1fs, kills %d, damage %d" % r)
	assert_float(r[0]).is_less(LIMIT)


func test_f_after_wave3_tapping() -> void:
	seed(7)
	var heavy: EnemyData = load("res://data/enemies/waegun_heavy.tres")
	var r := _run_kinds([SOLDIER, SOLDIER, GUNNER, SOLDIER, heavy], true)
	print("[sim] after, wave 3 tapping (no dodge): survived %.1fs, kills %d, damage %d" % r)
	assert_float(r[0]).is_less(LIMIT)  # 물결 3은 회피·기술 없이 버틸 수 없다
