extends SceneTree
## 큰 기술 컷인 한 장면을 찍는다 (무대 그림 위).
## godot --path . --resolution 720x1280 -s res://tools/shots/cutin_shot.gd -- <영웅 id> <진행 0~1> <출력 png>


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % args[0])
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/backgrounds/hansan_1592.png") if ResourceLoader.exists("res://assets/backgrounds/hansan_1592.png") else null
	bg.centered = false
	root.add_child(bg)
	var c := SkillCutin.new()
	c.def = hero.kit.counter
	c.hero = hero
	c.stage = SkillStageFeel.get_default()
	root.add_child(c)
	c.set_process(false)
	for f in 20:
		c._start_ms = Time.get_ticks_msec() - int(float(args[1]) * c.stage.cutin_time * 1000.0)
		c._canvas.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[2])
	quit()
