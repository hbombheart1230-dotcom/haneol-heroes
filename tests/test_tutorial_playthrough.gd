extends GdUnitTestSuite
## 조작 안내를 영웅마다 실제 손가락 입력으로 끝까지 해 본다 (막히는 단계가 없어야 한다).

const HEROES := [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]


func _main(hero: StringName, button: bool = false) -> Node:
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
	GameSettings.skill_button_enabled = button
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
	GameSettings.hero_id = &"yi_sun_sin"  # 다음 묶음이 설정 파일에서 다시 읽어도 기본 영웅
	GameSettings.skill_button_enabled = false
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func _play(hero: StringName, button: bool = false) -> void:
	var main := _main(hero, button)
	await get_tree().process_frame
	await get_tree().physics_frame
	var d := TutorialDriver.new(self, main)
	var stuck := await d.play_all()
	var total := 0.0
	for row in d.log:
		total += float(row[1])
	print("[tutorial %s] %s · total %.1fs" % [hero, d.log, total])
	assert_str(String(stuck)).override_failure_message("%s: stuck at %s (%s)" % [hero, stuck, d.log]).is_empty()
	assert_bool(main.spawner.active).is_true()  # 끝나면 적이 풀린다
	_cleanup(main)


func test_yi_sun_sin_finishes() -> void:
	await _play(&"yi_sun_sin")


func test_gwanggaeto_finishes() -> void:
	await _play(&"gwanggaeto")


func test_sejong_finishes() -> void:
	await _play(&"sejong")


func test_shin_saimdang_finishes() -> void:
	await _play(&"shin_saimdang")


func test_skill_button_on_still_finishes() -> void:  # 단추를 켜도 화면 제스처는 그대로
	await _play(&"gwanggaeto", true)
