extends SceneTree
## 설정 화면(나가기 단추·확인 상자)과 조작 안내 회피·반격 띠를 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/exit_dodge_shot.gd -- <출력 폴더>


func _initialize() -> void:
	_run()


var sv: SubViewport


func _shot(dir: String, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(dir.path_join(name))


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	sv = SubViewport.new()  # 창이 화면보다 작아져도 720x1280 그대로
	sv.size = Vector2i(720, 1280)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.5, 0.42)
	bg.size = Vector2(720, 1280)
	sv.add_child(bg)
	var s := SettingsScreen.new()
	s.size = Vector2(720, 1280)
	sv.add_child(s)
	await process_frame  # _ready(숨김)가 먼저 돌게
	s.open()
	await _shot(dir, "settings.png")
	var b := s.exit_rect().get_center()
	s.handle_touch(0, b, true)
	s.handle_touch(0, b, false)
	await _shot(dir, "settings_confirm.png")
	s.exit_mode = &"quit"
	s.queue_redraw()
	await _shot(dir, "settings_confirm_quit.png")
	s.close()
	paused = false
	var data: TutorialData = load("res://data/tutorial/controls.tres")
	var run := TutorialProgress.new(data)
	run.index = 2
	var o := TutorialOverlay.new()
	o.size = Vector2(720, 1280)
	sv.add_child(o)
	await process_frame
	o.open(run)
	o._t = 1.0
	await _shot(dir, "tutorial_evade.png")
	run.index = 3
	o._t = 0.7
	await _shot(dir, "tutorial_counter.png")
	quit()
