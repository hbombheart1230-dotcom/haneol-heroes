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
	sp.set_waves((load("res://data/stages/%s.tres" % stage) as StageTheme).waves)
	return sp


func _enemy(sp: EnemySpawner, d: EnemyData) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = d
	sp.add_child(e)
	e.set_physics_process(false)
	return e


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
	assert_int(sp.formations.size()).is_equal(4)  # 25%·10%를 한꺼번에 넘으면 1 + 2
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
