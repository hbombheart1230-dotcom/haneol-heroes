extends GdUnitTestSuite
## 첫 판 조작 안내: 단계 진행, 건너뛰기, 판에 붙었을 때 적·시간 멈춤과 풀림, 한 번만.

const DATA := preload("res://data/tutorial/controls.tres")


func test_data_steps_cover_controls() -> void:
	var evs := DATA.steps.map(func(s: TutorialStep) -> StringName: return s.event)
	assert_array(evs).is_equal([&"move", &"combo", &"skill_tap", &"skill_dash", &"skill_charge", &"evade", &"skill_counter", &"upgrade"])
	for s in DATA.steps:
		assert_str(s.caption).is_not_empty()
		assert_str(s.hint).is_not_empty()


func test_progress_advances_only_on_matching_event() -> void:
	var p := TutorialProgress.new(DATA)
	assert_bool(p.notify(&"dash")).is_false()  # 지금은 걷기 단계
	p.notify(&"move", 200.0)
	assert_float(p.ratio()).is_equal_approx(200.0 / 320.0, 0.001)
	assert_bool(p.notify(&"move", 200.0)).is_true()
	assert_int(p.index).is_equal(1)
	assert_bool(p.notify(&"skill_tap")).is_false()  # 연타 단계에선 마무리를 세지 않는다
	for ev in [&"combo", &"skill_tap", &"skill_dash", &"skill_charge", &"evade", &"skill_counter"]:
		assert_bool(p.notify(ev)).is_true()
	var done := [false]
	p.finished.connect(func() -> void: done[0] = true)
	p.notify(&"upgrade")
	assert_bool(p.is_done()).is_true()
	assert_bool(done[0]).is_true()


func test_skip_finishes() -> void:
	var p := TutorialProgress.new(DATA)
	var overlay: TutorialOverlay = auto_free(TutorialOverlay.new())
	overlay.size = Vector2(720, 1280)
	add_child(overlay)
	overlay.open(p)
	assert_bool(overlay.handle_touch(0, Vector2(360, 900), true)).is_false()  # 게임 입력은 그대로
	var c := overlay.skip_rect().get_center()
	assert_bool(overlay.handle_touch(0, c, true)).is_true()
	assert_bool(overlay.handle_touch(0, c, false)).is_true()
	assert_bool(p.is_done()).is_true()


func test_skill_slots_map_to_events() -> void:
	assert_str(String(TutorialDirector.skill_event(SkillCaster.Slot.TAP))).is_equal("skill_tap")
	assert_str(String(TutorialDirector.skill_event(SkillCaster.Slot.DASH))).is_equal("skill_dash")
	assert_str(String(TutorialDirector.skill_event(SkillCaster.Slot.CHARGE))).is_equal("skill_charge")
	assert_str(String(TutorialDirector.skill_event(SkillCaster.Slot.COUNTER))).is_equal("skill_counter")


func test_first_run_holds_enemies_and_time_until_done() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_object(main.tutorial_director).is_not_null()
	assert_bool(main.tutorial_director.running()).is_true()
	assert_bool(main.spawner.active).is_false()
	assert_bool(main.tutorial_overlay.is_open()).is_true()
	var t: float = main.state.elapsed
	for i in 10:
		await get_tree().physics_frame
	assert_float(main.state.elapsed).is_equal(t)  # 안내 중엔 시간이 가지 않는다
	main.player.dash_started.emit(Vector2.RIGHT)
	main.player.dash_started.emit(Vector2.RIGHT)
	assert_int(main.tutorial_director.run.index).is_equal(0)  # 아직 걷기 단계라 대시는 세지 않음
	main.tutorial_director.run.skip()
	assert_bool(GameSettings.tutorial_done).is_true()
	assert_bool(main.spawner.active).is_true()
	await get_tree().physics_frame
	assert_float(main.state.elapsed).is_greater(t)
	main.queue_free()
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func test_no_tutorial_once_done() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_object(main.tutorial_director).is_null()
	assert_bool(main.spawner.active).is_true()
	main.queue_free()


func test_upgrade_step_drops_practice_seals_and_picking_one_advances() -> void:
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
	await get_tree().process_frame
	var run: TutorialProgress = main.tutorial_director.run
	TutorialDriver.skip_to(run, &"upgrade")
	assert_str(String(run.current().event)).is_equal("upgrade")
	assert_bool(main.seal_choice.is_open()).is_true()  # 연습 카드가 나왔다
	main.seal_choice.pick(0)
	assert_bool(run.is_done()).is_true()  # 하나 고르면 끝 (마지막 단계)
	run.skip()
	main.queue_free()
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func _main_at_upgrade_step() -> Node:
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


func _advance_to_upgrade(run: TutorialProgress) -> void:
	TutorialDriver.skip_to(run, &"upgrade")


func _cleanup(main: Node) -> void:
	get_tree().paused = false
	main.queue_free()
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func test_skipping_with_practice_cards_open_keeps_cards_until_picked() -> void:
	var main := _main_at_upgrade_step()
	await get_tree().process_frame
	_advance_to_upgrade(main.tutorial_director.run)
	assert_bool(main.seal_choice.is_open()).is_true()
	main.tutorial_director.run.skip()
	assert_bool(main.seal_choice.is_open()).is_true()  # 건너뛰어도 카드는 고를 때까지 남는다
	main.seal_choice.pick(0)
	assert_bool(get_tree().paused).is_false()
	_cleanup(main)


func test_hero_without_upgrades_does_not_get_stuck_on_upgrade_step() -> void:
	var main := _main_at_upgrade_step()
	await get_tree().process_frame
	main.build.hero = main.build.hero.duplicate()
	main.build.hero.upgrade_pool = null
	_advance_to_upgrade(main.tutorial_director.run)
	assert_bool(main.seal_choice.is_open()).is_false()
	assert_bool(main.tutorial_director.run.is_done()).is_true()  # 넘어감 (마지막 단계)
	_cleanup(main)
