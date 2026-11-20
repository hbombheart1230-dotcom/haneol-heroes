extends SceneTree
## 맞는 반응 확인용: 같은 적을 맞기 전·맞은 순간(흰 번쩍임·움찔)·멈춤 뒤(맞는 동작 2번째 프레임)·끝난 뒤로 늘어놓고 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/hit_shot.gd -- <적 id> <출력 png>

const DT := 1.0 / 60.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # 루트가 준비된 뒤에 노드를 붙여야 set_physics_process(false)가 남는다
	var args := OS.get_cmdline_user_args()
	var data: EnemyData = load("res://data/enemies/%s.tres" % args[0])
	var st: StageTheme = load("res://data/stages/manchuria_395.tres")
	var bg := Sprite2D.new()
	bg.texture = load(st.background_path)
	bg.centered = false
	bg.region_enabled = true
	bg.region_rect = Rect2(bg.texture.get_size() * 0.5 - Vector2(360, 640), Vector2(720, 1280))
	root.add_child(bg)
	var target := Node2D.new()
	root.add_child(target)
	target.position = Vector2(360, 1200)
	## 단계별로 몇 프레임 진행할지: 맞기 전, 맞은 순간, 멈춤 직후, 맞는 동작 끝
	var steps := [-1, 0, 5, 30]
	for i in steps.size():
		var e: Enemy = load("res://scenes/enemy.tscn").instantiate()
		e.data = data
		root.add_child(e)
		e.set_physics_process(false)
		e.position = Vector2(180 + (i % 2) * 360, 380 + (i / 2) * 520)
		e.target = target
		e._physics_process(DT)
		if steps[i] >= 0:
			e.health.damage(3)
			for k in steps[i] + 1:
				e._physics_process(DT)
	for k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()
