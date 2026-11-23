extends SceneTree
## 대시 방향 나누기 · 회피 무적 테두리 (전·후 비교, 예전 코드에서도 돈다): 실제 한산 장면(ShotStage), 순신 오른쪽에 왜군 병사.
## 칸: 적 쪽으로 튕김(돌진) · 반대쪽으로 튕김(뒤로 빠지기) · 회피 직후 · 회피 0.7초 뒤.
## godot --path . --resolution 720x1280 -s res://tools/shots/dash_dir_shot.gd -- <출력 png>

const CROP := Vector2i(420, 420)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self)
	await _wait(3.2)
	var player := main.get_node("Player") as Player
	var atk := player.get_node_or_null("AutoAttack")
	if atk:
		atk.set_physics_process(false)
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var shots: Array[Image] = []
	for dir in [Vector2.RIGHT, Vector2.LEFT]:
		ShotStage.move_hero(main, spot)
		var e := spawner.spawn_at(data, spot + Vector2(150, 0))
		e.global_position = spot + Vector2(150, 0)
		e.health.max = 99999
		e.health.current = 99999
		e.attack = null
		e.set_physics_process(false)
		await _wait(0.3)
		player.request_dash(dir)
		for i in 3:
			await physics_frame
		await RenderingServer.frame_post_draw
		shots.append(_grab())
		await _wait(0.5)
		e.queue_free()
	ShotStage.move_hero(main, spot)
	await _wait(0.4)
	player.register_evade()
	await _wait(0.08)
	await RenderingServer.frame_post_draw
	shots.append(_grab())
	await _wait(0.62)
	await RenderingServer.frame_post_draw
	shots.append(_grab())
	var out := Image.create(CROP.x * 2, CROP.y * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i((i % 2) * CROP.x, (i / 2) * CROP.y))
	out.save_png(args[0])
	quit()


func _grab() -> Image:
	var img := root.get_texture().get_image()
	var c := (img.get_size() / 2 - CROP / 2 + Vector2i(0, -40)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
