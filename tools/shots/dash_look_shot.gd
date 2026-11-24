extends SceneTree
## 내닫기 생김새 나누기 전·후 (DashLookData): 실제 한산 장면, 3D 순신 오른쪽에 왜군 병사.
## 윗줄 = 치는 내닫기 (적 쪽): 대시 중 · 도착 직후 (칼 궤적). 아랫줄 = 피하는 내닫기 (반대쪽): 대시 중 · 도착 직후 (잔상·금테).
## "before"면 같은 판에서 dash_look을 비워 예전 그림, "nostrike"면 돌진 타격(dash_dir)만 비움 (치는 내닫기를 네 영웅으로 넓히기 전).
## godot --path . --resolution 720x1280 -s res://tools/shots/dash_look_shot.gd -- <before|nostrike|after> <출력 png> [영웅 id=yi_sun_sin]

const CROP := Vector2i(420, 420)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self, &"hansan_1592", StringName(args[2]) if args.size() > 2 else &"yi_sun_sin")
	await _wait(3.2)
	var player := main.get_node("Player") as Player
	if args[0] == "before":
		player.hero = player.hero.duplicate()
		player.hero.dash_look = null
	elif args[0] == "nostrike":
		player.hero = player.hero.duplicate()
		player.hero.dash_dir = null
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
		await _wait(0.8)
		player.request_dash(dir)
		for i in 4:
			await physics_frame
		await RenderingServer.frame_post_draw
		shots.append(_grab())
		while player.is_dashing():
			await physics_frame
		await _wait(0.04)
		await RenderingServer.frame_post_draw
		shots.append(_grab())
		await _wait(0.6)
		e.queue_free()
	var out := Image.create(CROP.x * 2, CROP.y * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i((i % 2) * CROP.x, (i / 2) * CROP.y))
	out.save_png(args[1])
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
