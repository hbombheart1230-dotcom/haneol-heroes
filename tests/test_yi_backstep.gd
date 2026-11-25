extends GdUnitTestSuite
## 순신 백스텝 시험 (사용자 승인 2026-11-25, 던파 백스텝 참고, DashDirData.backstep_*):
## ① 지금 치고 있는 대상(없으면 가장 가까운 적) 반대쪽 원뿔로 튕기면 백스텝 — 대상을 본 채, 일반 내닫기의 절반 거리, 빠르게.
## ② 연타 뒷동작을 끊는다 (내닫기와 같다). ③ 예고를 백스텝으로 빠지면 회피 → 반격 그대로. ④ 내닫기 횟수를 똑같이 쓴다.
## ⑤ 연달아 튕기면 둘째부터 일반 내닫기. ⑥ 내닫기 자동 기술은 백스텝에서 안 나간다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var atk: AutoAttack
var enemies: Array = []
var casts: Array = []


func before_test() -> void:
	BossSim.reset_globals()
	DashStyleRunner.clock = func() -> float: return 100.0
	enemies = []
	casts = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = YI
	add_child(player)
	player.set_physics_process(false)
	atk = AutoAttack.new()
	atk.name = "AutoAttack"
	atk.player = player
	atk.data = YI.attack
	atk.projectile_scene = PROJECTILE_SCENE
	atk.projectile_parent = self
	player.add_child(atk)
	atk.set_physics_process(false)
	caster = SkillCaster.new()
	caster.name = "SkillCaster"
	caster.player = player
	caster.kit = YI.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return enemies
	player.add_child(caster)
	caster.set_physics_process(false)
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: casts.append(s))


func after_test() -> void:
	for c in get_children():
		if c is Projectile or c is DamageZone or c is WaveRake:
			remove_child(c)
			c.free()
	BossSim.reset_globals()


func _enemy(at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = at
	e.health.max = 9999
	e.health.current = 9999
	e.attack = null
	enemies.append(e)
	return e


## 내닫기 끝까지 몸을 옮기고 간 거리·걸린 시간.
func _run_dash() -> Array:
	var from := player.global_position
	var t := 0.0
	while player.is_dashing() and t < 2.0:
		player.global_position += player.compute_velocity(DT) * DT
		caster.tick(DT, 10.0 + t)
		t += DT
	return [player.global_position.distance_to(from), t]


## ① 기준은 지금 치고 있는 대상: 가까운 적이 다른 쪽에 있어도, 친 적 반대쪽이면 백스텝 (대상을 본 채, 절반 거리, 빠르게).
func test_backstep_is_away_from_the_target_short_and_fast() -> void:
	var target := _enemy(Vector2(120, 0))
	_enemy(Vector2(-60, 70))  # 더 가까운 다른 적 (예전 기준이면 이 적과 견줘 옆이 된다)
	player.strike_target = target
	player.since_strike = 0.1
	assert_bool(player.request_dash(Vector2.LEFT)).is_true()
	assert_int(player.dash_kind).is_equal(DashDirection.Kind.BACK)
	assert_float(player.facing.x).is_greater(0.9)  # 대상을 본 채
	var r := _run_dash()
	var d := YI.dash_dir
	assert_float(r[0]).is_equal_approx(player.dash_distance * d.backstep_dist_mult, 6.0)
	assert_float(r[1]).is_less(player.dash_duration * 0.6)


## 친 지 오래면 가장 가까운 적 기준 (예전과 같다).
func test_old_target_falls_back_to_nearest() -> void:
	var target := _enemy(Vector2(120, 0))
	_enemy(Vector2(0, -100))
	player.strike_target = target
	player.since_strike = YI.dash_dir.backstep_target_memory + 0.5
	player.request_dash(Vector2.LEFT)  # 가장 가까운 적(위) 기준이면 옆
	assert_int(player.dash_kind).is_equal(DashDirection.Kind.SIDE)


## ⑤ 연달아 튕기면 둘째부터는 일반 내닫기 (멀리), ④ 횟수는 하나씩.
func test_second_flick_is_a_normal_dash() -> void:
	var target := _enemy(Vector2(120, 0))
	player.strike_target = target
	player.since_strike = 0.0
	var before := player.dash.charges if "charges" in player.dash else -1
	player.request_dash(Vector2.LEFT)
	assert_int(player.dash_kind).is_equal(DashDirection.Kind.BACK)
	_run_dash()
	player.since_strike = 0.0
	assert_bool(player.request_dash(Vector2.LEFT)).is_true()
	assert_int(player.dash_kind).is_equal(DashDirection.Kind.SIDE)
	var r := _run_dash()
	assert_float(r[0]).is_greater(player.dash_distance * 0.8)
	if before >= 0:
		assert_int(player.dash.charges).is_equal(before - 2)


## ⑥ 백스텝 길에 다른 적이 있어도 내닫기 자동 기술(파도격)이 나가지 않는다.
func test_no_dash_auto_skill_on_backstep() -> void:
	var target := _enemy(Vector2(120, 0))
	_enemy(Vector2(-70, 0))  # 뒤에 선 적: 백스텝 길 위
	player.strike_target = target
	player.since_strike = 0.0
	player.request_dash(Vector2.LEFT)
	assert_int(player.dash_kind).is_equal(DashDirection.Kind.BACK)
	_run_dash()
	assert_array(casts).not_contains([SkillCaster.Slot.DASH])


## ② 연타 뒷동작(4타 뒤 굳는 시간)을 끊는다: 백스텝이 시작되면 다음 평타를 막던 시간이 풀린다.
func test_backstep_cancels_finisher_recovery() -> void:
	var target := _enemy(Vector2(100, 0))
	caster.auto_attack()  # 게임에서는 첫 탭에 이어진다 (내닫기 → 휘두름 끊기)
	atk.busy_for(0.3)
	assert_float(atk.busy_left()).is_greater(0.0)
	player.strike_target = target
	player.since_strike = 0.0
	assert_bool(player.request_dash(Vector2.LEFT)).is_true()
	caster.tick(DT, 10.0)
	assert_float(atk.busy_left()).is_equal(0.0)


## 데이터로 끄고 켠다: 다른 세 영웅은 꺼져 있다 (예전 뒤로 빠지기).
func test_only_yi_has_backstep() -> void:
	assert_bool(YI.dash_dir.backstep_enabled).is_true()
	for id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		var d := (load("res://data/heroes/%s.tres" % id) as HeroData).dash_dir
		assert_bool(d == null or not d.backstep_enabled).override_failure_message(id).is_true()
