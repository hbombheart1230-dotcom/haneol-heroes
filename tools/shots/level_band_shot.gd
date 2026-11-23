extends SceneTree
## 판 화면의 레벨 띠를 찍는다: 평소 (점수 반짝·행동 점수 글씨), 레벨업 순간 ("레벨 업" + "카드 +1").
## godot --path . --resolution 720x1280 -s res://tools/shots/level_band_shot.gd -- <출력 폴더> [영웅 id]
## 설정은 시험용 파일에 쓴다 (사용자 설정을 건드리지 않음).


func _initialize() -> void:
	_run()


func _shot(path: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://"
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = StringName(args[1]) if args.size() > 1 else &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 90:  # 무대 문구가 지나가고 적이 나오게
		await physics_frame
	main.state.elapsed = 4.0
	main.progress.add_xp(main.progress.xp_to_next() - 5)
	main.progress.add_xp(2, &"combo")
	main.progress.add_xp(2, &"evade")
	main.progress.pending = 1
	await _shot(dir.path_join("band_normal.png"))
	main.progress.add_xp(4, &"counter")  # 레벨업
	for i in 8:
		await process_frame
	await _shot(dir.path_join("band_level_up.png"))
	quit()
