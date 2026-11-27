extends GdUnitTestSuite
## 우두머리·중간 우두머리가 그 전장의 원거리 대형을 부른다 (BossCalls, WaveSetData.call_formation).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func _spawner(stage: String) -> EnemySpawner:
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	add_child(sp)
	var hero := Node2D.new()
	add_child(auto_free(hero))
	sp.target = hero
	sp.max_alive = 40
	var ws := ((load("res://data/stages/%s.tres" % stage) as StageTheme).waves).duplicate() as WaveSetData
	ws.call_retry = 0.05  # 시험은 빨리 다시 본다
	sp.set_waves(ws)
	return sp


func _enemy(sp: EnemySpawner, d: EnemyData) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = d
	sp.add_child(e)
	e.set_physics_process(false)
	return e


## 다시 시도 타이머가 돌 만큼 실제 시간 동안 프레임을 넘긴다 (await_millis는 SceneTree 타이머를 돌리지 않는다).
func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await get_tree().process_frame


func test_boss_calls_formations_at_40_25_10() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var sp := _spawner("hansan_1592")
	var boss := _enemy(sp, st.boss)
	boss.health.current = roundi(boss.health.max * 0.5)
	BossCalls.on_damaged(boss)
	assert_int(sp.formations.size()).is_equal(0)  # 50%: 아직
	boss.health.current = roundi(boss.health.max * 0.39)
	BossCalls.on_damaged(boss)
	assert_int(sp.formations.size()).is_equal(1)  # 40%: 한 묶음
	BossCalls.on_damaged(boss)
	assert_int(sp.formations.size()).is_equal(1)  # 같은 문턱은 한 번만
	boss.health.current = roundi(boss.health.max * 0.09)
	BossCalls.on_damaged(boss)
	assert_int(sp.formations.size()).is_equal(3)  # 25%·10%를 한꺼번에 넘으면 마지막 문턱 몫(2)만
	assert_object(sp.formations[0].data).is_same(st.waves.call_formation)


func test_mid_boss_trio_calls_twice_while_others_remain() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var sp := _spawner("hansan_1592")
	var trio: Array = []
	for d: EnemyData in st.waves.waves[2].elite_group:
		trio.append(_enemy(sp, d))
	for i in trio.size():
		(trio[i] as Enemy).health.current = 0
		BossCalls.on_killed(trio[i], sp)
	assert_int(sp.formations.size()).is_equal(2)  # 셋 가운데 둘째까지 (마지막은 남은 셋이 없어 안 부름)



## Codex: 단계 전환 무적 중에는 부르지 않고, 무적이 끝난 뒤 다시 시도에서 부른다.
func test_boss_call_waits_out_phase_invuln() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var sp := _spawner("hansan_1592")
	var boss := _enemy(sp, st.boss)
	boss.phase_invuln = 10.0
	boss.health.current = roundi(boss.health.max * 0.39)
	BossCalls.on_damaged(boss)
	assert_int(sp.formations.size()).is_equal(0)
	boss.phase_invuln = 0.0
	await _wait_ms(400)
	assert_int(sp.formations.size()).is_equal(1)


## Codex: 처치 연출 중에는 부르지 않는다 (다시 시도가 다 지나면 버림).
func test_no_call_during_finale() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var sp := _spawner("hansan_1592")
	sp.waves.data.call_tries = 2
	var boss := _enemy(sp, st.boss)
	sp.finale_until_ms = GameTime.now_ms() + 100000
	boss.health.current = roundi(boss.health.max * 0.39)
	BossCalls.on_damaged(boss)
	await _wait_ms(400)
	assert_int(sp.formations.size()).is_equal(0)


## Codex: 중간 우두머리 부르기가 상한에 막혀 기다리는 사이 셋이 다 쓰러지면 대형은 나오지 않는다.
func test_mid_call_dropped_when_trio_is_gone() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var sp := _spawner("hansan_1592")
	var trio: Array = []
	for d: EnemyData in st.waves.waves[2].elite_group:
		trio.append(_enemy(sp, d))
	sp.max_alive = 0  # 자리 없음
	sp.waves.data.alive_cap_add = 0
	(trio[0] as Enemy).health.current = 0
	BossCalls.on_killed(trio[0], sp)
	assert_int(sp.formations.size()).is_equal(0)
	for i in range(1, trio.size()):
		(trio[i] as Enemy).health.current = 0
	sp.max_alive = 40  # 자리가 나도
	await _wait_ms(400)
	assert_int(sp.formations.size()).is_equal(0)


## Codex: 10%의 두 묶음은 아직 예고 중인 첫 묶음 자리까지 세어, 상한에 둘째 자리가 없으면 기다린다 (상한을 넘지 않게).
func test_second_group_waits_for_room_counting_warnings() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var sp := _spawner("hansan_1592")
	sp.waves.data.call_tries = 1
	var boss := _enemy(sp, st.boss)
	var n := sp.waves.data.call_formation.count
	sp.max_alive = 1 + n * 2 - 1 - sp.waves.data.alive_cap_add  # 우두머리 + 한 묶음만 들어가는 상한
	boss.health.current = roundi(boss.health.max * 0.09)
	boss.set_meta(&"boss_calls", 2)  # 40·25%는 지났고 10%(두 묶음)만
	BossCalls.on_damaged(boss)
	assert_int(sp.formations.size()).is_equal(1)
	assert_int(sp.alive_count() + sp._warnings).is_less_equal(sp.max_alive + sp.waves.data.alive_cap_add)
