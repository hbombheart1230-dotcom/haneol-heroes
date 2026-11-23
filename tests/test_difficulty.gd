extends GdUnitTestSuite
## 난이도 곡선: 단계별 배율, 표 끝 너머로 계속 오름, 적 사본(원본 그대로), 판에 적용, 이기면 단계 +1.

const CURVE := preload("res://data/difficulty/curve.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")


func test_tiers_rise_and_extrapolate() -> void:
	assert_float(CURVE.hp(0)).is_equal(1.0)
	assert_float(CURVE.damage(0)).is_equal(1.0)
	var prev := 0.0
	for t in 8:
		assert_float(CURVE.hp(t)).is_greater(prev)
		prev = CURVE.hp(t)
	assert_float(CURVE.hp(5)).is_equal_approx(CURVE.hp(3) + 2 * CURVE.per_loop_hp, 0.001)
	assert_float(CURVE.interval(30)).is_equal(CURVE.min_interval_mult)
	assert_float(CURVE.speed(30)).is_equal(CURVE.max_speed_mult)
	assert_int(CURVE.alive_add(5)).is_equal(CURVE.max_alive_add[3] + 2 * CURVE.per_loop_alive)


func test_scaled_copy_leaves_original() -> void:
	assert_object(CURVE.scaled(SOLDIER, 0)).is_same(SOLDIER)
	var hp := SOLDIER.max_hp
	var c := CURVE.scaled(SOLDIER, 2)
	assert_object(c).is_not_same(SOLDIER)
	assert_int(c.max_hp).is_equal(roundi(hp * CURVE.hp(2)))
	assert_int(SOLDIER.max_hp).is_equal(hp)
	if SOLDIER.attack:
		assert_object(c.attack).is_not_same(SOLDIER.attack)
		assert_int(c.attack.damage).is_equal(roundi(SOLDIER.attack.damage * CURVE.damage(2)))



## 보스 단계 공격·이어치기도 단계 배율을 받는다 (원본은 그대로, 같은 이어치기는 같은 사본).
func test_scaled_boss_phases_and_follow_ups() -> void:
	var boss: EnemyData = load("res://data/enemies/waegun_commander.tres")
	var c := CURVE.scaled(boss, 3)
	var k := CURVE.damage(3)
	for i in boss.phases.size():
		assert_object(c.phases[i]).is_not_same(boss.phases[i])
		assert_float(c.phases[i].hp_frac).is_equal(boss.phases[i].hp_frac)
		for j in boss.phases[i].patterns.size():
			var a: EnemyAttackData = boss.phases[i].patterns[j]
			var b: EnemyAttackData = c.phases[i].patterns[j]
			assert_int(b.damage).is_equal(roundi(a.damage * k))
			if a.follow_up:
				assert_int(b.follow_up.damage).is_equal(roundi(a.follow_up.damage * k))
				assert_object(b.follow_up).is_not_same(a.follow_up)
	assert_int(boss.phases[0].patterns[0].damage).is_equal(20)  # 원본 그대로


## 영웅별 보스 체력 배율과 난이도 단계는 곱으로 겹친다.
func test_hero_boss_hp_mult_composes_with_tier() -> void:
	var boss: EnemyData = load("res://data/enemies/waegun_commander.tres")
	var hero := HeroData.new()
	hero.boss_hp_mult = 1.5
	var c := CURVE.scaled(BossHpScale.for_hero(boss, hero), 2)
	assert_int(c.max_hp).is_equal(roundi(roundi(boss.max_hp * 1.5) * CURVE.hp(2)))
	assert_object(BossHpScale.for_hero(SOLDIER, hero)).is_same(SOLDIER)  # 보스만
	hero.boss_hp_mult = 1.0
	assert_object(BossHpScale.for_hero(boss, hero)).is_same(boss)


func test_run_uses_hero_tier_and_victory_raises_it() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {"yi_sun_sin": 2}
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_int(main.difficulty_tier()).is_equal(2)
	var st: StageTheme = main.run_config.stage
	var base: EnemyData = st.spawn_table[0]
	assert_int(main.spawner.spawn_table[0].max_hp).is_equal(roundi(base.max_hp * CURVE.hp(2)))  # 두 번 적용돼도 겹치지 않음
	assert_int(main.spawner.boss_data.max_hp).is_equal(roundi(st.boss.max_hp * CURVE.hp(2)))
	main.advance_stage()
	assert_int(int(GameSettings.hero_clears["yi_sun_sin"])).is_equal(3)
	get_tree().paused = false
	main.queue_free()
	GameSettings.hero_clears = {}
	GameSettings.hero_stages = {}
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()
