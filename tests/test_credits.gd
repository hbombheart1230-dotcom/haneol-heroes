extends GdUnitTestSuite
## "만든 이들" (출처·저작권 고지): 설정에서 열고 닫기, 의무 표시가 모두 들어 있는지, 엔진 고지, 끌어 넘기기, 자리.

var screen: SettingsScreen


func before_test() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	screen = auto_free(SettingsScreen.new())
	screen.size = Vector2(720, 1280)
	add_child(screen)  # 만든 이들은 설정 화면을 꽉 채운다 (앵커)


func after_test() -> void:
	get_tree().paused = false


func _tap(pos: Vector2) -> void:
	screen.handle_touch(0, pos, true)
	screen.handle_touch(0, pos, false)


func _tap_credits(pos: Vector2) -> void:
	screen.credits.handle_touch(0, pos, true)
	screen.credits.handle_touch(0, pos, false)


func test_settings_button_opens_and_close_returns_to_settings() -> void:
	screen.open()
	_tap(screen.credits_rect().get_center())
	assert_bool(screen.credits.is_open()).is_true()
	assert_bool(screen.is_open()).is_true()
	_tap_credits(screen.credits.close_rect().get_center())
	assert_bool(screen.credits.is_open()).is_false()
	assert_bool(screen.is_open()).is_true()  # 설정으로 돌아옴
	_tap(screen.credits_rect().get_center())
	screen.back()  # 안드로이드 뒤로 가기: 만든 이들만 닫는다
	assert_bool(screen.credits.is_open()).is_false()
	assert_bool(screen.is_open()).is_true()
	_tap(screen.credits_rect().get_center())
	screen.close()  # 설정을 닫으면 함께 닫힌다
	assert_bool(screen.credits.is_open()).is_false()
	screen.open()
	assert_bool(screen.credits.is_open()).is_false()


func test_required_notices_are_all_on_screen() -> void:
	var t := screen.credits.all_text()
	for must in ["국립한글박물관", "덕온공주체", "공공누리 제3유형",
			"(재)전주정보문화산업진흥원", "공유마당",
			"국립중앙박물관", "전 신사임당필 초충도(신수3550)",
			"국립문화유산연구원", "무용총 수렵도", "공공누리 제1유형",
			"Health, HitBoxes, HurtBoxes and HitScans", "Copyright (c) 2023 David Clutter",
			"Permission is hereby granted, free of charge",
			"This game uses Godot Engine", "Godot Engine contributors", "The FreeType Project"]:
		assert_bool(t.contains(must)).override_failure_message("없음: " + must).is_true()
	assert_int(t.count("공공누리 제1유형")).is_greater_equal(3)


func test_engine_notice_carries_every_third_party_license() -> void:
	var n := CreditsScreen.engine_notice()
	assert_bool(n.contains(Engine.get_license_text())).is_true()
	for comp in Engine.get_copyright_info():
		assert_bool(n.contains(str(comp["name"]))).is_true()
	for name in Engine.get_license_info():
		assert_bool(n.contains("——— %s ———" % name)).override_failure_message(str(name)).is_true()
	assert_str(CreditsScreen.freetype_years()).is_not_empty()


func test_data_is_one_line_per_asset() -> void:
	var d := CreditsData.load_default()
	assert_int(d.required.size()).is_equal(4)
	assert_int(d.licenses.size()).is_equal(1)
	assert_bool(d.thanks.size() > 0).is_true()


func test_long_text_scrolls_and_drag_does_not_close() -> void:
	screen.open()
	_tap(screen.credits_rect().get_center())
	var c := screen.credits
	await get_tree().process_frame
	await get_tree().process_frame
	var bar := c.scroll.get_v_scroll_bar()
	assert_float(bar.max_value).is_greater(c.scroll_rect().size.y * 3.0)  # 엔진 고지까지 길다
	var at := c.close_rect().get_center()
	c.handle_touch(0, at, true)
	for i in 5:
		c.handle_drag(0, Vector2(0, -60))
	c.handle_touch(0, at, false)
	assert_int(c.scroll.scroll_vertical).is_greater(0)
	assert_bool(c.is_open()).is_true()  # 끌어 넘긴 뒤 뗀 것은 닫지 않음


func test_button_fits_and_does_not_overlap() -> void:
	screen.open()
	var p := screen.panel_rect()
	assert_bool(Rect2(Vector2.ZERO, screen.size).encloses(p)).is_true()
	assert_bool(p.encloses(screen.credits_rect())).is_true()
	assert_bool(screen.credits_rect().intersects(screen.close_rect())).is_false()
	assert_bool(screen.credits_rect().intersects(screen.exit_rect())).is_false()
	var w := UiStyle.BODY_FONT.get_string_size("만든 이들", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	assert_float(w).is_less(screen.credits_rect().size.x - 24.0)
	var c := screen.credits
	assert_bool(c.scroll_rect().intersects(c.close_rect())).is_false()


func test_headings_follow_korean_wording_rules() -> void:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/wording_rules.json"))
	var text := screen.credits.all_text()
	for h in CreditsScreen.HEADINGS:
		assert_bool(text.contains(h)).is_true()
		for w in rules["banned"]:
			assert_bool(h.contains(w)).override_failure_message("%s ← %s" % [h, w]).is_false()
	assert_bool(text.contains("함께 쓴 도구")).is_true()
	assert_bool(text.contains("소프트웨어")).is_false()
