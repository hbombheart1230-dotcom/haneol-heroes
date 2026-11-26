extends SceneTree
## 조작 안내 단계마다 실제 판 화면을 찍는다 (이순신, 한산). 연타 단계는 영웅 넷 모두 (평타 설명이 다르다).
## godot --path . --resolution 720x1280 -s res://tools/shots/tutorial_shot.gd -- <출력 폴더> [phone]
## 출력: tutorial_<번호>_<event>.png, tutorial_combo_<영웅>.png (설정은 따로 된 파일에 써서 실제 설정을 건드리지 않는다)

const HEROES := [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]

var sv: SubViewport


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(path)


func _open(hero: StringName) -> Node:
	GameSettings.settings_path = "user://tutorial_shot_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = hero
	GameSettings.hero_stages = {}
	GameSettings.tutorial_enabled = true
	GameSettings.tutorial_done = false
	GameSettings.tutorial_seen_heroes = PackedStringArray()
	GameSettings.skill_button_enabled = false
	GameSettings.save_settings()  # TouchController가 판을 열 때 설정 파일을 다시 읽는다
	var main: Node = load("res://scenes/main.tscn").instantiate()
	sv.add_child(main)
	await _frames(3)
	return main


func _close(main: Node) -> void:
	main.tutorial_director.run.skip()
	paused = false
	main.queue_free()
	await _frames(2)


## 단계에 맞는 장면을 만든다 (회피: 붉은 먹 예고, 반격: 피한 직후).
func _stage(main: Node, ev: StringName) -> void:
	await _frames(20)
	var e: Enemy = main.tutorial_director.sparring.enemy
	if ev == &"evade" or ev == &"skill_counter":
		for i in 300:
			if e and is_instance_valid(e) and e.attack and e.attack.state == EnemyAttack.State.WINDUP \
					and e.attack.windup_ratio() > 0.6:
				break
			await process_frame
	if ev == &"skill_counter" and main.tutorial_director.run.current().event == &"evade":
		(main.player as Player).register_evade()  # 피했다 → 반격 단계 (반격 시간이 열린 화면)
		await _frames(4)
	main.tutorial_overlay._t = 0.55


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	DirAccess.make_dir_recursive_absolute(dir)
	sv = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	if OS.get_cmdline_user_args().has("phone"):  # 폰 1080×2400: 가로 720 기준으로 늘린 화면 (canvas_items + expand와 같게)
		sv.size = Vector2i(1080, 2400)
		sv.size_2d_override = Vector2i(720, 1600)
		sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var main := await _open(&"yi_sun_sin")
	var run: TutorialProgress = main.tutorial_director.run
	var n := 1
	for s: TutorialStep in run.data.steps.duplicate():
		if s.event != &"skill_counter":  # 반격 단계는 회피 단계에서 피해서 들어간다 (_stage)
			TutorialDriver.skip_to(run, s.event)
		await _stage(main, s.event)
		await _shot(dir.path_join("tutorial_%d_%s.png" % [n, s.event]))
		n += 1
	await _close(main)
	for h: StringName in HEROES:
		main = await _open(h)
		TutorialDriver.skip_to(main.tutorial_director.run, &"combo")
		await _stage(main, &"combo")
		await _shot(dir.path_join("tutorial_combo_%s.png" % h))
		await _close(main)
		for ev: StringName in [&"skill_tap", &"skill_dash", &"skill_charge", &"skill_counter"]:  # 기술 이름이 제목 옆에 (영웅 넷)
			main = await _open(h)
			TutorialDriver.skip_to(main.tutorial_director.run, &"evade" if ev == &"skill_counter" else ev)
			await _stage(main, ev)
			await _shot(dir.path_join("tutorial_%s_%s.png" % [h, ev]))
			await _close(main)
	quit()
