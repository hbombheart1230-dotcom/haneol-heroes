extends GdUnitTestSuite
## 첫 판 조작 안내: 단계 진행, 건너뛰기, 판에 붙었을 때 적·시간 멈춤과 풀림, 한 번만.

const DATA := preload("res://data/tutorial/controls.tres")


func test_data_steps_cover_controls() -> void:
	var evs := DATA.steps.map(func(s: TutorialStep) -> StringName: return s.event)
	assert_array(evs).is_equal([&"move", &"dash", &"skill_tap", &"skill_dash", &"skill_charge", &"wait"])
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
	p.notify(&"dash")
	assert_int(p.index).is_equal(1)  # 두 번 해야 넘어감
	p.notify(&"dash")
	for ev in [&"skill_tap", &"skill_dash", &"skill_charge"]:
		assert_bool(p.notify(ev)).is_true()
	var done := [false]
	p.finished.connect(func() -> void: done[0] = true)
	p.notify(&"wait", 4.1)
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
	assert_str(String(TutorialDirector.skill_event(SkillCaster.Slot.COUNTER))).is_equal("")


func test_first_run_holds_enemies_and_time_until_done() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
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
