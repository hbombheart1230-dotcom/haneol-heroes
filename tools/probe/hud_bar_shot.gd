extends SceneTree
## 영웅 체력 띠 (HUD 왼쪽 위) 캡처: 가득 / 절반 / 맞은 직후. godot --path . -s res://tools/probe/hud_bar_shot.gd -- <폴더> <접두사>
func _initialize() -> void:
	_run()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.tutorial_enabled = false
	GameSettings.want_stage_list = false
	GameSettings.save_settings()
	var sv := SubViewport.new()
	sv.size = Vector2i(1080, 2400)
	sv.size_2d_override = Vector2i(720, 1600)
	sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var m: Node = load("res://scenes/main.tscn").instantiate()
	sv.add_child(m)
	for i in 40:
		await process_frame
	m.player.health.damageable = false
	var mx: int = m.player.health.max
	for pair in [["full", 1.0], ["half", 0.5], ["low", 0.2]]:
		m.player.health.current = int(mx * pair[1])
		m.hud.badge.hurt_t = 0.0 if pair[0] != "low" else 0.3
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().get_region(Rect2i(0, 0, 540, 320)).save_png(out.path_join("%s_%s.png" % [a[1], pair[0]]))
	quit()
