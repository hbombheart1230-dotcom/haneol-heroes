extends SceneTree
## 굳힌 HUD (왼쪽 위 영웅 묶음, 위쪽 가운데 우두머리 띠)를 영웅마다 찍는다: 우두머리 띠가 떠 있고, 경지 오름 순간.
## godot --path . -s res://tools/shots/hud_layout_shot.gd -- <출력 폴더> [영웅 id ...]
## 720x1280 SubViewport에 판을 띄운다 (창이 화면보다 작아도). 설정은 시험용 파일에 쓴다.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


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
	var heroes: Array = args.slice(1) if args.size() > 1 else HEROES
	sv = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	for id: String in heroes:
		GameSettings.settings_path = GameSettings.test_path()
		GameSettings.title_seen = true
		GameSettings.opening_seen = true
		GameSettings.hero_picked = true
		GameSettings.hero_id = StringName(id)
		GameSettings.tutorial_done = true
		GameSettings.save_settings()
		var main: Node = load("res://scenes/main.tscn").instantiate()
		sv.add_child(main)
		for i in 90:  # 무대 문구가 지나가고 적이 나오게
			await physics_frame
		main.state.elapsed = 74.0
		main.spawner.spawn_boss()
		for i in 20:
			await physics_frame
		main.progress.add_xp(main.progress.xp_to_next() - 4)
		main.progress.add_xp(2, &"combo")
		main.progress.add_xp(4, &"counter")  # 경지 오름
		for i in 8:
			await process_frame
		await _shot(dir.path_join("hud_%s.png" % id))
		main.free()
		get_root().get_tree().paused = false
	quit()
