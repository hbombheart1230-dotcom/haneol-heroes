extends SceneTree
## 코드 동그라미·선 대신 붓 그림: 범위 고리, 먹 장판, 검기 획, 타격 튐, 근접 베기를 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/brush_shot.gd -- <출력 png>


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var st: StageTheme = load("res://data/stages/chochungdo.tres")
	ShotStage.backdrop(self, st)  # 실제 바닥 (floor_grade·빛 웅덩이·비네트·무대 확대)
	var fx := FxLayer.new()
	root.add_child(fx)
	fx.set_process(false)
	var sa: HeroData = load("res://data/heroes/shin_saimdang.tres")
	fx.add_ring(Vector2(200, 220), 150.0, 1.0, sa.kit.charge.fx_color)  # 화폭 예고 고리
	fx.add_ring(Vector2(520, 220), 110.0, 1.0, Color(1, 1, 1))
	fx.add_slash(Vector2(80, 470), Vector2(640, 470), 16.0, 1.0, Color(0.7, 0.95, 1.0))
	fx.add_spark(Vector2(360, 560), Color(1, 1, 1))
	for i in 4:  # 발묵 먹 장판
		var z := DamageZone.new()
		z.radius = 60.0
		z.duration = 9.0
		z.color = sa.kit.dash.fx_color
		z.position = Vector2(150 + i * 140, 720)
		root.add_child(z)
		z.set_process(false)
		z.set_physics_process(false)
		z.queue_redraw()
	var p := Player.new()
	p.position = Vector2(360, 1000)
	root.add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.player = p
	a.data = sa.attack
	p.add_child(a)
	a.set_physics_process(false)
	a._swing_dir = Vector2.RIGHT
	a._swing_time = 0.08
	a.queue_redraw()
	for f in 30:
		fx.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
