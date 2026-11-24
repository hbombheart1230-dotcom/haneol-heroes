extends GdUnitTestSuite
## 설정 "나가기": 한 번 더 묻고, 판 중이면 첫 화면으로 / 판 전 화면이면 앱 끝내기.

var screen: SettingsScreen


func before_test() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	screen = auto_free(SettingsScreen.new())
	screen.size = Vector2(720, 1280)
	add_child(screen)


func after_test() -> void:
	GameSettings.want_stage_list = false
	get_tree().paused = false
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"


func _tap(pos: Vector2) -> void:
	screen.handle_touch(0, pos, true)
	screen.handle_touch(0, pos, false)


func test_exit_button_fits_beside_close() -> void:
	screen.open()
	var p := screen.panel_rect()
	assert_bool(Rect2(Vector2.ZERO, screen.size).encloses(p)).is_true()
	assert_bool(p.encloses(screen.exit_rect())).is_true()
	assert_bool(screen.exit_rect().intersects(screen.close_rect())).is_false()
	assert_bool(p.encloses(screen.confirm_rect())).is_true()
	assert_bool(screen.confirm_rect().encloses(screen.confirm_yes_rect())).is_true()
	assert_bool(screen.confirm_rect().encloses(screen.confirm_no_rect())).is_true()


func test_exit_labels_fit_their_buttons() -> void:
	for mode in [&"title", &"quit"]:
		screen.exit_mode = mode
		var label: String = screen._exit_text(0)
		var f := UiStyle.BODY_FONT
		assert_float(f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * 0.85)).x).is_less(screen.exit_rect().size.x - 24.0)
		assert_float(f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(38 * 0.85)).x).is_less(screen.confirm_yes_rect().size.x - 24.0)
	screen.exit_mode = &"title"
	assert_str(screen._exit_text(0)).is_equal("전장 나가기")
	screen.exit_mode = &"quit"
	assert_str(screen._exit_text(0)).is_equal("끝내기")
	assert_str(screen._exit_text(1)).is_equal("끝낼까요?")


func test_exit_asks_first_and_cancel_keeps_settings_open() -> void:
	var got: Array = []
	screen.exit_confirmed.connect(func(m: StringName) -> void: got.append(m))
	screen.open()
	_tap(screen.exit_rect().get_center())
	assert_bool(screen.is_confirming()).is_true()
	assert_array(got).is_empty()
	var story := GameSettings.story_enabled
	_tap(screen.row_rect(SettingsScreen.ROWS.find(&"story")).get_center())  # 확인 중엔 줄을 바꾸지 않는다
	assert_bool(GameSettings.story_enabled).is_equal(story)
	assert_bool(screen.is_confirming()).is_true()
	_tap(screen.confirm_no_rect().get_center())
	assert_bool(screen.is_confirming()).is_false()
	assert_bool(screen.is_open()).is_true()
	assert_array(got).is_empty()


func test_confirm_closes_and_reports_mode() -> void:
	var got: Array = []
	screen.exit_confirmed.connect(func(m: StringName) -> void: got.append(m))
	screen.opened.connect(func() -> void: screen.exit_mode = &"quit")
	screen.open()
	assert_str(String(screen.exit_mode)).is_equal("quit")
	_tap(screen.exit_rect().get_center())
	_tap(screen.confirm_yes_rect().get_center())
	assert_bool(screen.is_open()).is_false()
	assert_array(got).is_equal([&"quit"])
	screen.open()
	assert_bool(screen.is_confirming()).is_false()  # 다시 열면 처음 상태


func test_back_to_title_resets_session_flags() -> void:
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.stage_picked = true
	GameSettings.back_to_title()
	assert_bool(GameSettings.title_seen).is_false()
	assert_bool(GameSettings.hero_picked).is_false()
	assert_bool(GameSettings.stage_picked).is_false()
	assert_bool(GameSettings.opening_seen).is_true()  # 오프닝 영상은 다시 틀지 않는다


func test_exit_mode_quits_on_title_and_goes_to_title_in_a_run() -> void:
	GameSettings.title_seen = false
	GameSettings.opening_seen = true
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_bool(main.waiting_pick).is_true()  # 첫 화면
	main.settings.open()
	assert_str(String(main.settings.exit_mode)).is_equal("quit")
	main.settings.close()
	main.waiting_pick = false  # 판 중
	main.settings.open()
	assert_str(String(main.settings.exit_mode)).is_equal("title")
	main.settings.close()
	get_tree().paused = false
	main.queue_free()


func test_exit_closes_open_upgrade_cards_first() -> void:
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.progress.pending += 1
	main.break_picks = 1  # 물결 모드(한산)는 숨 고르기 때만 연다
	main._offer_next()
	assert_bool(main.seal_choice.is_open()).is_true()
	main.flow.prepare_exit()
	assert_bool(main.seal_choice.is_open()).is_false()
	get_tree().paused = false
	main.queue_free()
