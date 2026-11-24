extends GdUnitTestSuite
## 조작 안내 회피·반격 단계: 연습 상대(피해 없음)가 서고, 회피·반격으로 넘어가고, 끝나면(건너뛰어도) 치운다.

const DATA := preload("res://data/tutorial/controls.tres")
const PRACTICE := preload("res://data/tutorial/practice_enemy.tres")


func _main() -> Node:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_enabled = true
	GameSettings.tutorial_done = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	return main


func _to_evade(run: TutorialProgress) -> void:
	TutorialDriver.skip_to(run, &"evade")


func _cleanup(main: Node) -> void:
	main.queue_free()
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func test_dodge_steps_follow_dash_and_use_the_practice_enemy() -> void:
	var evs := DATA.steps.map(func(s: TutorialStep) -> StringName: return s.event)
	assert_int(evs.find(&"evade")).is_greater(evs.find(&"skill_dash"))
	assert_int(evs.find(&"skill_counter")).is_equal(evs.find(&"evade") + 1)
	for s in DATA.steps:  # 회피·반격은 공격하는 상대, 연타·기술은 허수아비
		if s.event in [&"evade", &"skill_counter"]:
			assert_object(s.practice_enemy).is_same(PRACTICE)
		elif s.event in [&"combo", &"skill_tap", &"skill_dash", &"skill_charge"]:
			assert_object(s.practice_enemy).is_not_null()
			assert_object(s.practice_enemy.attack).is_null()
		else:
			assert_object(s.practice_enemy).is_null()


func test_practice_enemy_is_harmless_and_gives_no_xp() -> void:
	assert_int(PRACTICE.attack.damage).is_equal(0)
	assert_int(PRACTICE.contact_damage).is_equal(0)
	assert_int(PRACTICE.xp).is_equal(0)
	assert_bool(PRACTICE.is_elite or PRACTICE.is_boss).is_false()


func test_every_hint_line_fits_the_banner() -> void:
	for s in DATA.steps:
		for hint in [s.hint, s.button_hint, s.wave_hint] + s.hero_hints.values():
			for line in (hint as String).split("\n"):
				var w := UiStyle.BODY_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
				assert_float(w).override_failure_message("너무 긴 줄: %s (%d px)" % [line, w]).is_less_equal(440.0)


func test_evade_then_counter_advances_and_practice_enemy_comes_and_goes() -> void:
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	var run := dir.run
	assert_object(dir.sparring.enemy).is_null()  # 걷기 단계엔 상대 없음
	_to_evade(run)
	assert_str(String(run.current().event)).is_equal("evade")
	var e := dir.sparring.enemy
	assert_object(e).is_not_null()
	assert_object(e.data).is_same(PRACTICE)
	assert_float(e.global_position.distance_to(main.player.global_position)).is_less(DATA.practice_distance + 1.0)
	main.player.register_evade()  # 예고 공격을 대시로 피했다
	assert_str(String(run.current().event)).is_equal("skill_counter")
	assert_object(dir.sparring.enemy).is_same(e)  # 같은 상대가 그대로 선다
	var sc := main.player.get_node("SkillCaster") as SkillCaster
	sc.skill_cast.emit(SkillCaster.Slot.TAP, 0)
	assert_str(String(run.current().event)).is_equal("skill_counter")  # 그냥 톡은 반격이 아니다
	sc.skill_cast.emit(SkillCaster.Slot.COUNTER, 1)
	assert_str(String(run.current().event)).is_equal("upgrade")
	assert_object(dir.sparring.enemy).is_null()
	assert_bool(e.is_queued_for_deletion() or e.health.is_dead()).is_true()  # 단계를 마치면 쓰러진다
	run.skip()
	_cleanup(main)


func test_killed_practice_enemy_comes_back() -> void:
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	_to_evade(dir.run)
	var e := dir.sparring.enemy
	e.health.damage(e.health.max)
	assert_object(dir.sparring.enemy).is_null()
	dir.tick(DATA.practice_respawn * 0.5)
	assert_object(dir.sparring.enemy).is_null()
	dir.tick(DATA.practice_respawn * 0.6)
	assert_object(dir.sparring.enemy).is_not_null()
	assert_int(main.progress.pending).is_equal(0)  # 경험치 없음 → 강화 고르기가 생기지 않는다
	dir.run.skip()
	_cleanup(main)


func test_skip_with_practice_enemy_out_removes_it() -> void:
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	_to_evade(dir.run)
	var e := dir.sparring.enemy
	dir.run.skip()
	assert_bool(e.is_queued_for_deletion() or e.health.is_dead()).is_true()
	assert_object(dir.sparring.enemy).is_null()
	assert_bool(main.spawner.active).is_true()
	_cleanup(main)


func test_hero_without_counter_skips_counter_step() -> void:
	var main := _main()
	await get_tree().process_frame
	var sc := main.player.get_node("SkillCaster") as SkillCaster
	sc.kit = sc.kit.duplicate()
	sc.kit.counter = null
	var run: TutorialProgress = main.tutorial_director.run
	_to_evade(run)
	main.player.register_evade()
	assert_str(String(run.current().event)).is_equal("upgrade")  # 막히지 않는다
	assert_object(main.tutorial_director.sparring.enemy).is_null()
	run.skip()
	_cleanup(main)


func test_practice_enemy_really_walks_up_and_winds_up_a_harmless_attack() -> void:
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	_to_evade(dir.run)
	var e := dir.sparring.enemy
	var hp: int = main.player.health.current
	var wound := false
	for i in 60 * 6:
		await get_tree().physics_frame
		if is_instance_valid(e) and e.attack and e.attack.state == EnemyAttack.State.WINDUP:
			wound = true
	assert_bool(wound).is_true()  # 서 있으면 붉은 원을 그린다
	assert_int(main.player.health.current).is_equal(hp)  # 맞아도 닳지 않는다
	assert_str(String(dir.run.current().event)).is_equal("evade")  # 피하지 않으면 넘어가지 않는다
	dir.run.skip()
	_cleanup(main)


func test_real_dash_out_of_the_red_circle_advances_the_dodge_step() -> void:
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	_to_evade(dir.run)
	var e := dir.sparring.enemy
	for i in 60 * 6:  # 붉은 원이 그려질 때까지 기다린다
		await get_tree().physics_frame
		if is_instance_valid(e) and e.attack and e.attack.state == EnemyAttack.State.WINDUP:
			break
	assert_int(e.attack.state).is_equal(EnemyAttack.State.WINDUP)
	var p: Player = main.player
	var away := (p.global_position - e.global_position).normalized()
	p.request_dash(away if away != Vector2.ZERO else Vector2.DOWN)  # 실제 대시로 원 밖으로
	for i in 60:
		await get_tree().physics_frame
		if dir.run.current().event != &"evade":
			break
	assert_str(String(dir.run.current().event)).is_equal("skill_counter")
	dir.run.skip()
	_cleanup(main)


func test_practice_enemy_is_sturdy_and_ignores_hp_multipliers() -> void:
	assert_int(PRACTICE.max_hp).is_greater_equal(1000)  # 잡몹(수십~백) 수준이 아니다
	assert_float(PRACTICE.attack.windup).is_greater_equal(1.0)  # 예고가 길다
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	_to_evade(dir.run)
	var e := dir.sparring.enemy
	assert_bool(TutorialSparring.is_practice(e)).is_true()
	assert_float(e.hp_mult).is_equal(1.0)
	assert_int(e.health.max).is_equal(PRACTICE.max_hp)
	dir.run.skip()
	_cleanup(main)


func test_practice_enemy_never_dies_before_the_step_is_done() -> void:
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	_to_evade(dir.run)
	var e := dir.sparring.enemy
	for i in 30:  # 더 빨라진 평타·기술이 연달아 때려도
		e.health.damage(int(e.health.max * 0.3))
		dir.tick(1.0 / 60.0)
		assert_bool(e.health.is_dead()).is_false()
	assert_object(dir.sparring.enemy).is_same(e)
	dir.run.skip()
	_cleanup(main)


## 근접 잡몹 수 배율(WaveSwarm)을 켜도 연습 상대는 그대로: 물결이 아니라 spawn_at으로 서고 체력 배율도 없다.
func test_practice_enemy_ignores_the_swarm_multiplier() -> void:
	var main := _main()
	await get_tree().process_frame
	var dir: TutorialDirector = main.tutorial_director
	if main.spawner.waves:  # D안: 무대 기본이 이미 1.5 (캐시된 무대 자원을 바꾸지 않는다)
		assert_float(main.spawner.waves.data.melee_count_mult).is_greater(1.0)
	_to_evade(dir.run)
	var e := dir.sparring.enemy
	assert_bool(TutorialSparring.is_practice(e)).is_true()
	assert_int(e.health.max).is_equal(PRACTICE.max_hp)
	assert_int(main.spawner.get_tree().get_nodes_in_group("enemies").filter(func(n: Node) -> bool: return n is Enemy and not n.is_queued_for_deletion()).size()).is_equal(1)
	dir.run.skip()
	_cleanup(main)
