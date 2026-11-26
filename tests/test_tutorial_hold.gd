extends GdUnitTestSuite
## 조작 안내 반격 단계: 회피 뒤 우연한 톡으로 안내 글을 읽기도 전에 지나가지 않고, 반격이 끝난 뒤 강화 패도 바로 덮지 않는다
## (사용자: "첫 선택 카드가 너무 빨리 떠서 틈이 없어").

const DATA := preload("res://data/tutorial/controls.tres")


func _counter() -> TutorialStep:
	for s in DATA.steps:
		if s.event == &"skill_counter":
			return s
	return null


func _main(hero: StringName) -> Node:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = hero
	GameSettings.hero_stages = {}
	GameSettings.stage_picked = false
	GameSettings.tutorial_enabled = true
	GameSettings.want_stage_list = false
	GameSettings.tutorial_done = false
	GameSettings.tutorial_seen_heroes = PackedStringArray()
	GameSettings.skill_button_enabled = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	return main


func _cleanup(main: Node) -> void:
	if main.tutorial_director and main.tutorial_director.run:
		main.tutorial_director.run.skip()
	get_tree().paused = false
	main.queue_free()
	GameSettings.tutorial_done = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()


func test_data_has_a_read_time_and_a_card_delay() -> void:
	assert_float(_counter().min_show).is_equal_approx(2.0, 0.001)
	assert_str(_counter().done_hint).is_not_empty()
	for s in DATA.steps:
		if s.event == &"upgrade":
			assert_float(s.enter_delay).is_equal_approx(1.5, 0.001)
		elif s.event != &"skill_counter":
			assert_float(s.min_show).is_equal(0.0)  # 다른 단계의 속도는 그대로
			assert_float(s.enter_delay).is_equal(0.0)


func test_counter_done_early_is_held_until_the_read_time_passes() -> void:
	var p := TutorialProgress.new(DATA)
	TutorialDriver.skip_to(p, &"skill_counter")
	assert_bool(p.notify(&"skill_counter")).is_false()  # 우연한 톡: 해냈지만 넘기지 않는다
	assert_str(String(p.current().event)).is_equal("skill_counter")
	assert_bool(p.held()).is_true()
	p.elapse(1.9)
	assert_str(String(p.current().event)).is_equal("skill_counter")
	p.elapse(0.2)
	assert_str(String(p.current().event)).is_equal("upgrade")
	assert_bool(p.held()).is_false()


func test_counter_after_the_read_time_passes_at_once() -> void:
	var p := TutorialProgress.new(DATA)
	TutorialDriver.skip_to(p, &"skill_counter")
	p.elapse(2.5)
	assert_bool(p.notify(&"skill_counter")).is_true()
	assert_str(String(p.current().event)).is_equal("upgrade")


func test_other_steps_still_advance_at_once() -> void:
	var p := TutorialProgress.new(DATA)
	assert_bool(p.notify(&"move", 400.0)).is_true()
	assert_bool(p.notify(&"combo")).is_true()


func test_practice_card_waits_after_the_counter_step() -> void:
	var main := _main(&"yi_sun_sin")
	await get_tree().process_frame
	await get_tree().physics_frame
	var dir: TutorialDirector = main.tutorial_director
	var run: TutorialProgress = dir.run
	TutorialDriver.skip_to(run, &"skill_counter")
	run.notify(&"skill_counter")  # 피하자마자 톡
	dir.tick(0.1)
	assert_str(String(run.current().event)).is_equal("skill_counter")
	assert_bool(main.seal_choice.is_open()).is_false()
	dir.tick(2.0)  # 읽힐 시간이 찼다 → 강화 단계, 그래도 패는 아직
	assert_str(String(run.current().event)).is_equal("upgrade")
	assert_bool(main.seal_choice.is_open()).is_false()
	dir.tick(1.0)
	assert_bool(main.seal_choice.is_open()).is_false()
	dir.tick(0.6)
	assert_bool(main.seal_choice.is_open()).is_true()
	_cleanup(main)


## 연타 많은 사람: 회피 뒤 곧바로 톡톡톡 — 안내 글이 뜬 지 2초가 차기 전엔 반격 단계에 머물고, 그 사이 패는 안 뜬다.
func test_tap_spam_after_the_dodge_does_not_rush_past_the_counter_step() -> void:
	var main := _main(&"yi_sun_sin")
	await get_tree().process_frame
	await get_tree().physics_frame
	var d := TutorialDriver.new(self, main)
	var run: TutorialProgress = main.tutorial_director.run
	TutorialDriver.skip_to(run, &"evade")
	var tries := 0
	while run.current() != null and run.current().event == &"evade" and tries < 6:
		await d.act(&"evade")
		tries += 1
	assert_str(String(run.current().event)).is_equal("skill_counter")
	for k in 8:  # 1초 남짓 톡톡톡
		await d.tap()
		await d.seconds(0.1)
	if run.step_time < 2.0:  # 바쁜 기계에서 톡톡톡이 2초를 넘겼으면 단계가 넘어가는 게 맞다 (흔들리지 않게)
		assert_str(String(run.current().event)).is_equal("skill_counter")
		assert_bool(main.seal_choice.is_open()).is_false()
	_cleanup(main)


## 반격 뒤 설정 화면 등으로 멈춘 동안엔 패 기다림이 흐르지 않는다 (멈춘 채 패가 열려 닫을 때 풀려 버리는 것을 막는다).
func test_paused_game_does_not_count_the_card_delay() -> void:
	var main := _main(&"yi_sun_sin")
	await get_tree().process_frame
	await get_tree().physics_frame
	var dir: TutorialDirector = main.tutorial_director
	var run: TutorialProgress = dir.run
	TutorialDriver.skip_to(run, &"skill_counter")
	run.notify(&"skill_counter")
	dir.tick(2.1)
	assert_str(String(run.current().event)).is_equal("upgrade")
	get_tree().paused = true
	dir.tick(5.0)
	assert_bool(main.seal_choice.is_open()).is_false()
	get_tree().paused = false
	dir.tick(1.6)
	assert_bool(main.seal_choice.is_open()).is_true()
	_cleanup(main)
