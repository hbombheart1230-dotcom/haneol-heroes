extends GdUnitTestSuite
## 설정 화면: 효과음·음악 크기(버스), 타격 진동, 이야기 켬/끔, 스킬 단추, 저장, 톱니 단추.

var screen: SettingsScreen


func before_test() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	screen = auto_free(SettingsScreen.new())
	screen.size = Vector2(720, 1280)
	add_child(screen)


func after_test() -> void:
	GameSettings.want_stage_list = false
	get_tree().paused = false
	GameSettings.sfx_volume = 0.8
	GameSettings.music_volume = 0.8
	GameSettings.haptics_enabled = true
	GameSettings.story_enabled = true
	GameSettings.skill_button_enabled = false
	GameSettings.enemy_hp_bars = true
	GameSettings.show_stats = true
	GameSettings.tutorial_enabled = true
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
	GameSettings.tutorial_enabled = true
	for row in [&"haptics", &"story", &"skill_button", &"enemy_hp", &"stats", &"tutorial"]:
		var before := bool(screen.value_of(row))
		_tap(screen.row_rect(SettingsScreen.ROWS.find(row)).get_center())
		assert_bool(bool(screen.value_of(row))).is_equal(not before)
	GameSettings.haptics_enabled = true
	GameSettings.story_enabled = true
	GameSettings.load_settings()  # 저장된 값으로 되돌아간다
	assert_bool(GameSettings.haptics_enabled).is_false()
	assert_bool(GameSettings.story_enabled).is_false()
	assert_bool(GameSettings.skill_button_enabled).is_true()
	assert_bool(GameSettings.enemy_hp_bars).is_false()
	assert_bool(GameSettings.show_stats).is_false()
	assert_bool(GameSettings.tutorial_enabled).is_false()  # 조작 안내 끔이 저장됨


func test_dev_stats_start_off_and_ignore_old_key() -> void:
	# 화면 아래 "대시 미달…" 같은 개발용 글자는 처음엔 끔. 예전 키(처음 값 켬)로 저장된 폰도 꺼진 채로.
	var cfg := ConfigFile.new()
	cfg.set_value("display", "show_stats", true)
	cfg.save(GameSettings.settings_path)
	GameSettings.show_stats = true
	GameSettings.load_settings()
	assert_bool(GameSettings.show_stats).is_false()


func test_tutorial_setting_starts_on_and_turning_on_shows_it_again() -> void:
	var fresh := ConfigFile.new()  # 저장 파일에 값이 없으면 (처음 설치) 켬
	fresh.save(GameSettings.settings_path)
	GameSettings.tutorial_enabled = false
	GameSettings.load_settings()
	assert_bool(GameSettings.tutorial_enabled).is_true()
	assert_bool(bool(screen.value_of(&"tutorial"))).is_true()
	screen.set_value(&"tutorial", false)
	GameSettings.tutorial_done = true  # 이번 실행에서 이미 봄
	screen.set_value(&"tutorial", true)
	assert_bool(GameSettings.tutorial_done).is_false()  # 다시 켜면 다음 판에 나온다


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
	GameSettings.opening_seen = true
	GameSettings.hero_picked = false
	GameSettings.hero_id = &""  # 마지막 영웅 없음 → 영웅 고르기
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
	assert_bool(main.stage_select.is_open()).is_true()  # 이야기 없이 바로 전장 목록
	main.stage_select.press(0)
	assert_bool(main.waiting_pick).is_false()
	main.settings.set_value(&"skill_button", true)  # 설정에서 바꾸면 조작에 바로 반영
	assert_bool((main.get_node("TouchController") as TouchController).skill_button_enabled).is_true()
	get_tree().paused = false
	main.queue_free()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"


func test_panel_fits_screen_with_all_rows() -> void:
	screen.open()
	var vp := Rect2(Vector2.ZERO, screen.size)
	assert_bool(vp.encloses(screen.panel_rect())).is_true()
	assert_bool(screen.panel_rect().encloses(screen.close_rect())).is_true()
	assert_float(screen.row_rect(SettingsScreen.ROWS.size() - 1).end.y).is_less_equal(screen.close_rect().position.y)


func test_enemy_bars_only_for_hurt_non_boss_when_enabled() -> void:
	var bars: EnemyBars = auto_free(EnemyBars.new())
	add_child(bars)
	var scene := preload("res://scenes/enemy.tscn")
	var hurt: Enemy = scene.instantiate()
	hurt.data = preload("res://data/enemies/chaser.tres")
	add_child(auto_free(hurt))
	hurt.set_physics_process(false)
	var full: Enemy = scene.instantiate()
	full.data = preload("res://data/enemies/chaser.tres")
	add_child(auto_free(full))
	full.set_physics_process(false)
	var boss: Enemy = scene.instantiate()
	boss.data = preload("res://data/enemies/boss_general.tres")
	add_child(auto_free(boss))
	boss.set_physics_process(false)
	hurt.health.damage(1)
	boss.health.damage(1)
	GameSettings.enemy_hp_bars = true
	assert_int(bars.bars().size()).is_equal(1)
	assert_float(bars.bars()[0][1]).is_less(1.0)
	GameSettings.enemy_hp_bars = false
	assert_int(bars.bars().size()).is_equal(0)
