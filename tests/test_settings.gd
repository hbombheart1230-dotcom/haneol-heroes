extends GdUnitTestSuite
## 설정 화면: 효과음·음악 크기(버스), 타격 진동, 이야기 켬/끔, 스킬 단추, 저장, 톱니 단추.

var screen: SettingsScreen


func before_test() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	screen = auto_free(SettingsScreen.new())
	screen.size = Vector2(720, 1280)
	add_child(screen)


func after_test() -> void:
	get_tree().paused = false
	GameSettings.sfx_volume = 0.8
	GameSettings.music_volume = 0.8
	GameSettings.haptics_enabled = true
	GameSettings.story_enabled = true
	GameSettings.skill_button_enabled = false
	GameSettings.apply_audio()
	GameSettings.save_settings()


func _tap(pos: Vector2) -> void:
	screen.handle_touch(0, pos, true)
	screen.handle_touch(0, pos, false)


func test_bus_layout_has_music_and_sfx() -> void:
	assert_int(AudioServer.get_bus_index(&"Music")).is_greater(0)
	assert_int(AudioServer.get_bus_index(&"SFX")).is_greater(0)


func test_sliders_set_bus_volume_and_zero_mutes() -> void:
	screen.open()
	var i := SettingsScreen.ROWS.find(&"music")
	var s := screen.slider_rect(i)
	screen.handle_touch(0, Vector2(s.position.x + s.size.x * 0.5, s.get_center().y), true)
	screen.handle_drag(0, Vector2(s.position.x - 50, s.get_center().y))
	screen.handle_touch(0, Vector2(s.position.x - 50, s.get_center().y), false)
	assert_float(GameSettings.music_volume).is_equal(0.0)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music"))).is_true()
	assert_bool(screen.is_open()).is_true()  # 밀대를 끌다 놓아도 닫히지 않는다
	var j := SettingsScreen.ROWS.find(&"sfx")
	var t := screen.slider_rect(j)
	_tap(Vector2(t.position.x + t.size.x * 0.5, t.get_center().y))
	assert_float(GameSettings.sfx_volume).is_equal_approx(0.5, 0.001)
	var bus := AudioServer.get_bus_index(&"SFX")
	assert_bool(AudioServer.is_bus_mute(bus)).is_false()
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(linear_to_db(0.5), 0.01)


func test_toggles_flip_and_persist() -> void:
	screen.open()
	for row in [&"haptics", &"story", &"skill_button"]:
		var before := bool(screen.value_of(row))
		_tap(screen.row_rect(SettingsScreen.ROWS.find(row)).get_center())
		assert_bool(bool(screen.value_of(row))).is_equal(not before)
	GameSettings.haptics_enabled = true
	GameSettings.story_enabled = true
	GameSettings.load_settings()  # 저장된 값으로 되돌아간다
	assert_bool(GameSettings.haptics_enabled).is_false()
	assert_bool(GameSettings.story_enabled).is_false()
	assert_bool(GameSettings.skill_button_enabled).is_true()


func test_haptics_respects_setting() -> void:
	GameSettings.haptics_enabled = false
	assert_bool(Haptics.pulse(30)).is_false()
	GameSettings.haptics_enabled = true
	assert_bool(Haptics.pulse(30, 0.4)).is_true()
	assert_array(Haptics.last).is_equal([30, 0.4])


func test_open_pauses_and_close_restores() -> void:
	get_tree().paused = false
	screen.open()
	assert_bool(get_tree().paused).is_true()
	_tap(screen.close_rect().get_center())
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	get_tree().paused = true
	screen.open()
	_tap(Vector2(5, 5))  # 판 밖을 눌러도 닫힘, 원래 멈춤 상태 유지
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_true()


func test_gear_button_opens_screen() -> void:
	var gear: SettingsButton = auto_free(SettingsButton.new())
	gear.size = Vector2(720, 1280)
	gear.screen = screen
	add_child(gear)
	assert_bool(gear.handle_touch(0, Vector2(100, 600), true)).is_false()  # 다른 곳은 넘긴다
	var c := gear.center()
	assert_bool(gear.handle_touch(0, c, true)).is_true()
	assert_bool(gear.handle_touch(0, c, false)).is_true()
	assert_bool(screen.is_open()).is_true()


func test_story_off_skips_prologue_and_hero_story() -> void:
	GameSettings.story_enabled = false
	GameSettings.title_seen = false
	GameSettings.hero_picked = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var title: TitleScreen = main.title_screen
	title._process(0.5)
	var b := title.button_rect().get_center()
	title.handle_touch(0, b, true)
	title.handle_touch(0, b, false)
	assert_bool(main.story_intro.is_open()).is_false()
	var sel: HeroSelect = main.hero_select
	var c := sel.slot_rect(0).get_center()
	sel.handle_touch(0, c, true)
	sel.handle_touch(0, c, false)
	assert_bool(main.story_intro.is_open()).is_false()
	assert_bool(main.waiting_pick).is_false()
	main.settings.set_value(&"skill_button", true)  # 설정에서 바꾸면 조작에 바로 반영
	assert_bool((main.get_node("TouchController") as TouchController).skill_button_enabled).is_true()
	get_tree().paused = false
	main.queue_free()
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
