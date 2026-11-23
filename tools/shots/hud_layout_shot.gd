extends SceneTree
## HUD 배치 시안: 판 화면을 자리(Hud.layout)마다 찍는다 — 보스 띠가 떠 있고, 레벨업 순간 + 방금 맞은 때.
## godot --path . -s res://tools/shots/hud_layout_shot.gd -- <출력 폴더> [영웅 id]
## 720x1280 SubViewport에 판을 띄운다 (창이 화면보다 작아도). 설정은 시험용 파일에 쓴다.


func _initialize() -> void:
	_run()


var sv: SubViewport


func _shot(path: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(path)


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
	sv = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	sv.add_child(main)
	for i in 90:  # 무대 문구가 지나가고 적이 나오게
		await physics_frame
	main.state.elapsed = 74.0
	main.spawner.spawn_boss()
	for i in 20:
		await physics_frame
	for layout in 3:
		main.hud.layout = layout
		main.progress.add_xp(main.progress.xp_to_next() - 4)
		main.progress.add_xp(2, &"combo")
		main.progress.add_xp(4, &"counter")  # 레벨업
		main.player.health.current = main.player.health.max - 12  # 방금 맞음 (체력은 넉넉히)
		for i in 8:
			await process_frame
		await _shot(dir.path_join("hud_layout_%s.png" % ["a", "b", "c"][layout]))
		for i in 90:  # 연출이 끝나게
			await process_frame
	quit()
