extends SceneTree
## 영웅 승리 동작(HeroVictory) 캡처: 영웅마다 3D·구운 그림 두 줄, 승리 동작을 틀고 0.2초마다 한 칸.
## 창 모드: godot --path . -s res://tools/live3d/victory_shot.gd -- <출력 png>

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const SETTING := "hh/art/live3d"
const CELL := 260
const SHOTS := 7
const STEP := 0.2


func _initialize() -> void:
	_run()


func _run() -> void:
	var rows := HEROES.size() * 2
	var out := Image.create(SHOTS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.2, 0.27, 0.3))
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.27, 0.3)
	bg.size = Vector2(CELL, CELL)
	vp.add_child(bg)
	var was: Variant = ProjectSettings.get_setting(SETTING, true)
	for r in rows:
		var hero: HeroData = load("res://data/heroes/%s.tres" % HEROES[r / 2])
		ProjectSettings.set_setting(SETTING, r % 2 == 0)  # 짝수 줄 3D, 홀수 줄 구운 그림
		var p := Player.new()
		var h := Health.new()
		h.name = "Health"
		p.add_child(h)
		p.hero = hero
		p.position = Vector2(CELL * 0.5, CELL * 0.8)
		vp.add_child(p)
		var v := PlayerView.new()
		v.name = "PlayerView"
		v.player = p
		p.add_child(v)
		for k in 4:
			await physics_frame
		p.set_physics_process(false)
		p.facing = Vector2.DOWN
		HeroVictory.play(vp, p, func() -> void: pass)
		for c in SHOTS:
			await create_timer(STEP if c > 0 else 0.02).timeout
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			out.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, r * CELL))
		p.queue_free()
		await process_frame
	ProjectSettings.set_setting(SETTING, was)
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
