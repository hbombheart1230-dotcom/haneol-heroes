extends GdUnitTestSuite
## 조작 안내는 영웅마다 처음 한 번만 저절로 나온다: 끝내거나 건너뛰거나 도중에 나가도, 새 판·앱 다시 켬 뒤에 그 영웅은 다시 안 뜬다.
## 다른 영웅으로 처음 나가면 그 영웅 안내가 뜬다. (베타 보고: 출전할 때마다 처음부터 다시 나왔다 — 본 표시가 저장되지 않았다.)


func _main(hero: StringName = &"yi_sun_sin") -> Node:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = hero
	GameSettings.hero_stages = {}
	GameSettings.stage_picked = false
	GameSettings.want_stage_list = false
	GameSettings.save_settings()  # 판이 시작하며 저장 파일에서 영웅을 다시 읽으니 먼저 적어 둔다
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	return main


## 처음 설치처럼: 저장 파일을 비우고 안내를 켠 채 시작.
func _fresh_install() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	DirAccess.remove_absolute(GameSettings.settings_path)
	GameSettings.tutorial_enabled = true
	GameSettings.tutorial_done = false
	GameSettings.tutorial_seen_heroes = PackedStringArray()
	GameSettings.save_settings()


## 앱을 껐다 켠 것처럼: 메모리 값은 처음 값으로, 저장 파일에서 다시 읽는다.
func _relaunch() -> void:
	GameSettings.tutorial_enabled = true
	GameSettings.tutorial_done = false
	GameSettings.tutorial_seen_heroes = PackedStringArray()
	GameSettings.load_settings()


## 앱을 껐다 켠 것처럼 (본 영웅 표시는 저장 파일에서 다시 읽는다).
func _relaunch_keep_seen() -> void:
	GameSettings.tutorial_enabled = true
	GameSettings.tutorial_done = false
	GameSettings.tutorial_seen_heroes = PackedStringArray()
	GameSettings.load_settings()


func _end(main: Node) -> void:
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame


func after_test() -> void:
	GameSettings.tutorial_done = true  # 다른 시험에 안내가 새지 않게
	GameSettings.tutorial_seen_heroes = PackedStringArray()
	GameSettings.tutorial_enabled = true
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func test_first_run_shows_it() -> void:
	_fresh_install()
	var main := _main()
	await get_tree().process_frame
	assert_object(main.tutorial_director).is_not_null()
	await _end(main)


func test_skipped_then_new_run_and_relaunch_do_not_show_it() -> void:
	_fresh_install()
	var main := _main()
	await get_tree().process_frame
	main.tutorial_director.run.skip()
	await _end(main)
	var again := _main()  # 새 판 (같은 실행)
	await get_tree().process_frame
	assert_object(again.tutorial_director).is_null()
	await _end(again)
	_relaunch()  # 앱 다시 켬
	var after := _main()
	await get_tree().process_frame
	assert_object(after.tutorial_director).is_null()
	await _end(after)


func test_finished_then_relaunch_does_not_show_it() -> void:
	_fresh_install()
	var main := _main()
	await get_tree().process_frame
	var d: TutorialDirector = main.tutorial_director
	while d.run and not d.run.is_done():  # 모든 단계를 끝까지 알려 끝낸다
		var s := d.run.current()
		d.run.notify(s.event, maxf(s.amount, 1.0))
	assert_bool(GameSettings.tutorial_seen(&"yi_sun_sin")).is_true()
	await _end(main)
	_relaunch()
	var after := _main()
	await get_tree().process_frame
	assert_object(after.tutorial_director).is_null()
	await _end(after)


func test_leaving_midway_does_not_force_it_again() -> void:
	_fresh_install()
	var main := _main()
	await get_tree().process_frame
	assert_object(main.tutorial_director).is_not_null()
	await _end(main)  # 마치지도 건너뛰지도 않고 판을 나갔다
	_relaunch()
	var after := _main()
	await get_tree().process_frame
	assert_object(after.tutorial_director).is_null()
	await _end(after)


func test_turning_setting_on_shows_it_once_more() -> void:
	_fresh_install()
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.mark_tutorial_seen(&"yi_sun_sin")
	GameSettings.save_settings()
	var screen: SettingsScreen = auto_free(SettingsScreen.new())
	add_child(screen)
	assert_bool(bool(screen.value_of(&"tutorial"))).is_false()  # 이미 봤다: 꺼진 것으로 보인다
	screen.set_value(&"tutorial", true)
	_relaunch()
	var main := _main()
	await get_tree().process_frame
	assert_object(main.tutorial_director).is_not_null()
	await _end(main)


func test_each_hero_gets_it_once_separately() -> void:
	_fresh_install()
	var a := _main(&"yi_sun_sin")
	await get_tree().process_frame
	assert_object(a.tutorial_director).is_not_null()
	await _end(a)
	var b := _main(&"sejong")  # 다른 영웅으로 처음 출전: 그 영웅 안내
	await get_tree().process_frame
	assert_object(b.tutorial_director).is_not_null()
	await _end(b)
	_relaunch_keep_seen()
	for h in [&"yi_sun_sin", &"sejong"]:  # 둘 다 다시 켜도 안 뜬다
		var m := _main(h)
		await get_tree().process_frame
		assert_object(m.tutorial_director).is_null()
		await _end(m)
	var c := _main(&"gwanggaeto")  # 아직 안 한 영웅은 뜬다
	await get_tree().process_frame
	assert_object(c.tutorial_director).is_not_null()
	await _end(c)


func test_replay_in_settings_is_for_current_hero_only() -> void:
	_fresh_install()
	GameSettings.mark_tutorial_seen(&"yi_sun_sin")
	GameSettings.mark_tutorial_seen(&"sejong")
	GameSettings.hero_id = &"sejong"
	GameSettings.save_settings()
	var screen: SettingsScreen = auto_free(SettingsScreen.new())
	add_child(screen)
	screen.set_value(&"tutorial", true)
	assert_bool(GameSettings.tutorial_seen(&"sejong")).is_false()
	assert_bool(GameSettings.tutorial_seen(&"yi_sun_sin")).is_true()


func test_director_reads_skill_names_from_hero_data() -> void:
	_fresh_install()
	var main := _main(&"yi_sun_sin")
	await get_tree().process_frame
	var names: Dictionary = main.tutorial_overlay.skill_names
	var kit: SkillKit = main.player.hero.kit
	assert_str(names[&"skill_tap"]).is_equal(kit.tap.display_name)
	assert_str(names[&"skill_dash"]).is_equal(kit.dash.display_name)
	assert_str(names[&"skill_charge"]).is_equal(kit.charge.display_name)
	assert_str(names[&"skill_counter"]).is_equal(kit.counter.display_name)
	assert_str(names[&"skill_tap"]).is_not_empty()
	await _end(main)


func test_skill_name_fits_next_to_caption_for_every_hero() -> void:
	var data := load("res://data/tutorial/controls.tres") as TutorialData
	for h in [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]:
		var kit := (load("res://data/heroes/%s.tres" % h) as HeroData).kit
		for pair in [[&"skill_tap", kit.tap], [&"skill_dash", kit.dash], [&"skill_charge", kit.charge], [&"skill_counter", kit.counter]]:
			for s in data.steps:
				if s.event != pair[0]:
					continue
				var cap_w := UiStyle.TITLE_FONT.get_string_size(s.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
				var px := BossBanner.fit_px((pair[1] as SkillDef).display_name, TutorialOverlay.SKILL_NAME_PX, 440.0 - cap_w - TutorialOverlay.SKILL_NAME_GAP)
				assert_int(px).is_greater_equal(24)  # 너무 작아지지 않는다
