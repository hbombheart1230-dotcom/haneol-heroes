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
	run.notify(&"move", 400.0)
	run.notify(&"dash")
	run.notify(&"dash")


func _cleanup(main: Node) -> void:
	main.queue_free()
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func test_dodge_steps_follow_dash_and_use_the_practice_enemy() -> void:
	var evs := DATA.steps.map(func(s: TutorialStep) -> StringName: return s.event)
	assert_int(evs.find(&"evade")).is_equal(evs.find(&"dash") + 1)
	assert_int(evs.find(&"skill_counter")).is_equal(evs.find(&"evade") + 1)
	for s in DATA.steps:
		assert_bool(s.practice_enemy != null).is_equal(s.event in [&"evade", &"skill_counter"])


func test_practice_enemy_is_harmless_and_gives_no_xp() -> void:
	assert_int(PRACTICE.attack.damage).is_equal(0)
	assert_int(PRACTICE.contact_damage).is_equal(0)
	assert_int(PRACTICE.xp).is_equal(0)
	assert_bool(PRACTICE.is_elite or PRACTICE.is_boss).is_false()


func test_new_hint_lines_fit_the_banner() -> void:
	for s in DATA.steps:
		if s.practice_enemy == null:
			continue
		for hint in [s.hint, s.button_hint]:
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
	assert_str(String(run.current().event)).is_equal("skill_tap")
	assert_object(dir.sparring.enemy).is_null()
	assert_bool(e.is_queued_for_deletion()).is_true()
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
	assert_bool(e.is_queued_for_deletion()).is_true()
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
	assert_str(String(run.current().event)).is_equal("skill_tap")  # 막히지 않는다
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
