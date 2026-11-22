extends GdUnitTestSuite
## 물결 모드의 강화 고르기: 숨 고르기마다 한 번만 (연달아 여러 번 뜨지 않음), 그 한 번이 여러 단계를 올린다.


func after_test() -> void:
	get_tree().paused = false
	GameTime.reset()
	GameSettings.hero_clears = {}
	GameSettings.hero_stages = {}


func _main() -> Node:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.save_settings()  # TouchController가 판을 열 때 설정 파일을 다시 읽는다 (앞 묶음이 남긴 영웅이 섞이지 않게)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(auto_free(main))
	return main


func test_one_pick_per_breather_grants_two_stacks() -> void:
	var main := _main()
	await get_tree().process_frame
	assert_object(main.spawner.waves).is_not_null()  # 한산 = 물결 모드
	assert_int(main.pick_gain(false)).is_equal(2)
	assert_int(main.pick_gain(true)).is_equal(1)
	main.progress.pending = 3  # 물결 동안 레벨이 세 번 올랐어도
	main._on_breather(false)
	assert_bool(main.is_choosing()).is_true()
	var u: UpgradeDef = main.seal_choice.choices[0]
	main.seal_choice.pick(0)
	assert_bool(main.is_choosing()).is_false()  # 연달아 또 뜨지 않는다
	assert_int(int(main.progress.stacks[u.id])).is_equal(mini(2, u.max_stacks))
	assert_int(main.break_picks).is_equal(0)
	main._offer_next()
	assert_bool(main.is_choosing()).is_false()  # 다음 숨 고르기까지 없음
	main._on_breather(false)
	assert_bool(main.is_choosing()).is_true()


func test_elite_major_is_the_one_pick_of_that_breather() -> void:
	var main := _main()
	await get_tree().process_frame
	main.major_pending = 1
	main._on_breather(false)
	assert_bool(main.is_choosing()).is_true()
	assert_bool(main.seal_choice.major).is_true()
	main.seal_choice.pick(0)
	assert_bool(main.is_choosing()).is_false()
