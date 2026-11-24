extends SceneTree
## "만든 이들" 화면 사진 (1080×2400 폰, 화면 크기 720×1600): 설정 → 만든 이들 맨 위, 그리고 엔진 고지까지 넘긴 것.
## godot --path . -s res://tools/shots/credits_shot.gd -- <출력 폴더>


func _initialize() -> void:
	_run()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	var sv := SubViewport.new()
	sv.size = Vector2i(1080, 2400)
	sv.size_2d_override = Vector2i(720, 1600)
	sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var bg := ColorRect.new()  # 판 화면 대신 어두운 바탕
	bg.color = Color(0.1, 0.12, 0.16)
	bg.size = Vector2(720, 1600)
	sv.add_child(bg)
	GameSettings.settings_path = GameSettings.test_path()
	var s := SettingsScreen.new()
	s.size = Vector2(720, 1600)
	sv.add_child(s)
	await process_frame
	s.open()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out.path_join("settings.png"))
	s.handle_touch(0, s.credits_rect().get_center(), true)
	s.handle_touch(0, s.credits_rect().get_center(), false)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out.path_join("credits_top.png"))
	s.credits.scroll_by(-1200.0)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out.path_join("credits_engine.png"))
	print("credits shots saved to ", out)
	quit()
