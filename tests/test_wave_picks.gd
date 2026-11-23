extends GdUnitTestSuite
## 물결 모드의 강화 고르기: 레벨업으로 적립한 카드를 숨 고르기에서 고른다 (LevelRules.plan) — 한 번에 최대 두 번,
## 넘치면 합쳐 여러 단계, 보스 직전엔 전부, 최소 한 장 보장. 정예 큰 변형은 그 위에 따로.


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
	GameSettings.want_stage_list = false
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.save_settings()  # TouchController가 판을 열 때 설정 파일을 다시 읽는다 (앞 묶음이 남긴 영웅이 섞이지 않게)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(auto_free(main))
	return main


func _pick_all(main: Node) -> Array:
	var got := []
	while main.is_choosing():
		var u: UpgradeDef = main.seal_choice.choices[0]
		var before := int(main.progress.stacks.get(u.id, 0))
		main.seal_choice.pick(0)
		got.append(int(main.progress.stacks.get(u.id, 0)) - before)
	return got


func test_banked_cards_are_picked_at_most_twice_per_breather() -> void:
	var main := _main()
	await get_tree().process_frame
	assert_object(main.spawner.waves).is_not_null()  # 한산 = 물결 모드
	assert_object(main.progress.rules()).is_not_null()
	main.progress.pending = 4  # 물결 동안 레벨이 네 번 올랐다
	main._on_breather(false)
	assert_bool(main.is_choosing()).is_true()
	var gains := _pick_all(main)
	assert_int(gains.size()).is_equal(2)  # 한 번에 최대 두 번 (연달아 세 번 이상 뜨지 않는다)
	assert_int(gains[0] + gains[1]).is_less_equal(3)  # 카드 셋 = 하나는 두 단계로 합침
	assert_int(main.progress.pending).is_equal(1)  # 남은 한 장은 다음 숨 고르기로
	main._offer_next()
	assert_bool(main.is_choosing()).is_false()  # 다음 숨 고르기까지 없음


func test_breather_guarantees_one_card_even_without_levels() -> void:
	var main := _main()
	await get_tree().process_frame
	main.progress.pending = 0
	main._on_breather(false)
	assert_bool(main.is_choosing()).is_true()  # 서툴러도 물결마다 하나는 고른다
	assert_int(_pick_all(main).size()).is_equal(1)
	assert_int(main.progress.pending).is_equal(0)


func test_last_breather_spends_every_card() -> void:
	var main := _main()
	await get_tree().process_frame
	main.spawner.waves.phase = WaveRunner.Phase.BOSS_WAIT  # 마지막 물결 뒤 = 보스 직전
	main.progress.pending = 5
	main._on_breather(false)
	var gains := _pick_all(main)
	assert_int(gains.size()).is_equal(3)
	assert_int(main.progress.pending).is_equal(0)


func test_elite_major_comes_on_top_of_the_cards() -> void:
	var main := _main()
	await get_tree().process_frame
	main.major_pending = 1
	main.progress.pending = 1
	main._on_breather(false)
	assert_bool(main.is_choosing()).is_true()
	assert_bool(main.seal_choice.major).is_true()  # 큰 변형 먼저
	main.seal_choice.pick(0)
	assert_bool(main.is_choosing()).is_true()  # 이어서 적립 카드 (큰 변형이 카드 몫을 빼앗지 않는다)
	assert_bool(main.seal_choice.major).is_false()
	main.seal_choice.pick(0)
	assert_bool(main.is_choosing()).is_false()
