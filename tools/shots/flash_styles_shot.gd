extends SceneTree
## 맞은 순간 몸 색 비교안 (HitReactionData.hit_flash_style)을 한 장에: 한산 바닥 위 왜군 병사 넷 —
## 맞기 전 · 0 흰 번쩍임 · 1 붉은 실루엣 · 2 먹빛 실루엣 + 인주색 테두리 (번쩍임 한가운데 칸).
## godot --path . --resolution 720x1280 -s res://tools/shots/flash_styles_shot.gd -- <출력 png>

const DT := 1.0 / 60.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var st: StageTheme = load("res://data/stages/hansan_1592.tres")
	var bg := Sprite2D.new()
	bg.texture = load(st.background_path)
	bg.centered = false
	bg.region_enabled = true
	bg.region_rect = Rect2(bg.texture.get_size() * 0.5 - Vector2(360, 640), Vector2(720, 1280))
	if st.floor_value < 1.0 or st.floor_saturation < 1.0:
		bg.modulate = Color(st.floor_value, st.floor_value, st.floor_value)
	root.add_child(bg)
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var rd := Feedback.feel_data().reaction_data()
	for i in 4:
		var e: Enemy = load("res://scenes/enemy.tscn").instantiate()
		e.data = data
		root.add_child(e)
		e.set_physics_process(false)
		e.position = Vector2(180 + (i % 2) * 360, 380 + (i / 2) * 520)
		e._physics_process(DT)
		if i > 0:
			var style := i - 1
			rd.hit_flash_style = style
			e.sprite.set_instance_shader_parameter(&"flash", 1.0 if style > 0 else rd.flash_white)
			e.sprite.set_instance_shader_parameter(&"flash_color", rd.flash_body())
			e.sprite.set_instance_shader_parameter(&"flash_rim", rd.flash_rim())
	rd.hit_flash_style = 0
	for k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	quit()
