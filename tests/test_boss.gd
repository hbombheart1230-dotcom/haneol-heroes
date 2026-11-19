extends GdUnitTestSuite
## 2단계 첫 보스: 영역 모양(부채꼴·돌진·충격파), 패턴 순환, 등장·처치 승리.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS := preload("res://data/enemies/boss_general.tres")
const CHASER := preload("res://data/enemies/chaser.tres")
const DT := 1.0 / 60.0

var player: Player


func before_test() -> void:
	EnemyAttack.active_windups = 0
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.global_position = Vector2.ZERO


func after_test() -> void:
	EnemyAttack.active_windups = 0


func _pattern(kind: EnemyAttackData.Kind) -> EnemyAttackData:
	for p in BOSS.patterns:
		if (p as EnemyAttackData).kind == kind:
			return p
	return null


func _attack_from(kind: EnemyAttackData.Kind, self_pos: Vector2) -> EnemyAttack:
	var a := EnemyAttack.new(_pattern(kind), 0.0)
	a.tick(DT, self_pos, player)
	return a


func _run(a: EnemyAttack, self_pos: Vector2, seconds: float) -> Array:
	var out: Array = []
	var t := 0.0
	while t < seconds:
		t += DT
		player.compute_velocity(DT)
		var r := a.tick(DT, self_pos, player)
		if r != EnemyAttack.Result.NONE:
			out.append(r)
	return out


func test_boss_data() -> void:
	assert_bool(BOSS.is_boss).is_true()
	assert_int(BOSS.patterns.size()).is_equal(3)
	for p in BOSS.patterns:
		assert_bool((p as EnemyAttackData).bypass_cap).is_true()


# --- 영역 모양 ---

func test_cone_area() -> void:
	var a := _attack_from(EnemyAttackData.Kind.CONE, Vector2(150, 0))  # 플레이어는 왼쪽
	assert_bool(a.contains(Vector2(0, 0))).is_true()
	assert_bool(a.contains(Vector2(300, 0))).is_false()  # 등 뒤
	assert_bool(a.contains(Vector2(150 - 300, 0))).is_false()  # 사거리 밖


func test_charge_area_and_end() -> void:
	var a := _attack_from(EnemyAttackData.Kind.CHARGE, Vector2(300, 0))
	assert_bool(a.contains(Vector2(0, 0))).is_true()
	assert_bool(a.contains(Vector2(0, 200))).is_false()  # 옆으로 벗어남
	assert_vector(a.charge_end()).is_equal_approx(Vector2(300 - _pattern(EnemyAttackData.Kind.CHARGE).length, 0), Vector2(0.01, 0.01))


func test_shockwave_area_is_around_self() -> void:
	var a := _attack_from(EnemyAttackData.Kind.SHOCKWAVE, Vector2(100, 0))
	assert_bool(a.contains(Vector2(100, 200))).is_true()
	assert_bool(a.contains(Vector2(100, 400))).is_false()


func test_cone_hits_standing_player() -> void:
	var a := _attack_from(EnemyAttackData.Kind.CONE, Vector2(150, 0))
	var r := _run(a, Vector2(150, 0), 1.0)
	assert_array(r).is_equal([EnemyAttack.Result.HIT])


func test_dash_out_of_charge_lane_is_immediate_evade() -> void:
	var a := _attack_from(EnemyAttackData.Kind.CHARGE, Vector2(300, 0))
	player.request_dash(Vector2.DOWN)
	player.global_position = Vector2(0, 200)  # 돌진 경로 밖으로
	a.tick(DT, Vector2(300, 0), player)
	assert_float(player.skill_invuln_left()).is_greater(0.0)
	var r := _run(a, Vector2(300, 0), 1.0)
	assert_array(r).is_equal([EnemyAttack.Result.EVADED])


# --- 패턴·제한 ---

func test_patterns_rotate_after_each_attack() -> void:
	var a := EnemyAttack.new(BOSS.patterns[0], 0.0)
	a.set_patterns(BOSS.patterns)
	var kinds: Array = []
	var t := 0.0
	player.grant_invulnerability(100.0)
	while t < 8.0 and kinds.size() < 3:
		t += DT
		if a.state == EnemyAttack.State.READY and (kinds.is_empty() or kinds.back() != a.data.kind):
			kinds.append(a.data.kind)
		a.tick(DT, Vector2(100, 0), player)
	assert_int(kinds.size()).is_equal(3)
	assert_bool(kinds[0] != kinds[1] and kinds[1] != kinds[2]).is_true()


func test_boss_ignores_concurrent_cap() -> void:
	EnemyAttack.active_windups = EnemyAttack.max_concurrent
	var a := _attack_from(EnemyAttackData.Kind.CONE, Vector2(100, 0))
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)
	var normal := EnemyAttack.new(CHASER.attack, 0.0)
	normal.tick(DT, Vector2(50, 0), player)
	assert_int(normal.state).is_equal(EnemyAttack.State.READY)


func test_boss_enemy_charges_to_lane_end() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = BOSS
	e.target = player
	add_child(auto_free(e))
	e.global_position = Vector2(300, 0)
	e.attack = EnemyAttack.new(_pattern(EnemyAttackData.Kind.CHARGE), 0.0)
	player.grant_invulnerability(100.0)
	for i in 70:
		e._physics_process(DT)
	for i in 20:
		await get_tree().process_frame
	assert_float(e.global_position.x).is_less(0.0)
	assert_bool(e.is_in_group(Enemy.BOSS_GROUP)).is_true()


# --- 등장·승리 ---

func test_spawner_spawns_boss_once_at_time() -> void:
	var s: EnemySpawner = auto_free(EnemySpawner.new())
	s.enemy_scene = ENEMY_SCENE
	s.target = player
	s.boss_data = BOSS
	s.boss_time = 1.0
	s.max_alive = 0  # 일반 적은 안 나오게
	add_child(s)
	var spawned: Array = []
	s.boss_spawned.connect(func(b: Enemy) -> void: spawned.append(b))
	s.tick(0.5)
	assert_int(spawned.size()).is_equal(0)
	s.tick(0.6)
	s.tick(5.0)
	assert_int(spawned.size()).is_equal(1)
	assert_bool((spawned[0] as Enemy).data.is_boss).is_true()


func test_boss_defeat_is_victory() -> void:
	var g := GameState.new(60.0)
	g.tick(45.0)
	g.boss_defeated()
	assert_int(g.result).is_equal(GameState.Result.VICTORY)
	assert_bool(g.boss_killed).is_true()


func test_main_scene_boss_kill_ends_with_victory() -> void:
	_skip_hero_select()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var boss := spawner.spawn_boss()
	assert_object(boss).is_not_null()
	boss.health.kill()
	await get_tree().physics_frame
	assert_int(main.state.result).is_equal(GameState.Result.VICTORY)
	assert_bool(main.state.boss_killed).is_true()
	get_tree().paused = false
	main.queue_free()


func test_shockwave_follows_boss_during_telegraph() -> void:
	# Codex c1b3e34 회귀: 예고 중 보스가 밀려나면 충격파 원도 따라간다
	var a := _attack_from(EnemyAttackData.Kind.SHOCKWAVE, Vector2(100, 0))
	a.tick(DT, Vector2(400, 0), player)  # 보스가 오른쪽으로 밀려남
	assert_vector(a.aim_origin).is_equal(Vector2(400, 0))
	assert_bool(a.contains(Vector2(400, 200))).is_true()
	assert_bool(a.contains(Vector2(100, -200))).is_false()


## 메인 씬 테스트: 영웅 고르기 화면 없이 이순신으로, 실제 설정 파일은 건드리지 않는다.
func _skip_hero_select() -> void:
	GameSettings.settings_path = "user://test_settings.cfg"
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()
