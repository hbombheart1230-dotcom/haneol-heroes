extends SceneTree
## 느려짐 표시 찍기 (강화 패 "진한 먹·긴 그림자"): 실제 무대에 왜군 셋을 세우고 각각 느려짐(약하게 짧게 / 세게 / 세게 길게)을 걸어
## 0·1·2·3초에 찍어 한 줄로 붙인다. 적은 움직이지 않는다 (표시만 본다).
## godot --path . --resolution 720x1280 -s res://tools/shots/slow_mark_shot.gd -- <출력 png>

const SLOWS := [[0.7, 2.0], [0.32, 2.0], [0.32, 3.0]]  # [속도 배율, 초]
const CROP := Vector2i(560, 360)


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = await ShotStage.open(self, &"hansan_1592", &"yi_sun_sin")
	await _wait(4.5)  # 무대 이름 띠가 걷힌 뒤
	var player := main.get_node("Player") as Player
	player.grant_invulnerability(9999.0)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var foes: Array[Enemy] = []
	for i in SLOWS.size():
		var e := spawner.spawn_at(load("res://data/enemies/waegun_soldier.tres"), player.global_position + Vector2(-160 + 160 * i, 150))
		e.set_physics_process(false)
		e.health.max = 99999
		e.health.current = 99999
		foes.append(e)
	await _wait(0.3)
	for i in foes.size():
		foes[i].slow(SLOWS[i][0], SLOWS[i][1])
	var out: Array[Image] = []
	var t0 := Time.get_ticks_msec()
	for at in [0.05, 1.0, 2.0, 2.8]:
		while (Time.get_ticks_msec() - t0) / 1000.0 < at:
			var el := (Time.get_ticks_msec() - t0) / 1000.0
			for i in foes.size():  # 물리를 끈 적도 느려짐 시간이 실제 시간대로 흐르게
				foes[i]._slow_left = maxf(float(SLOWS[i][1]) - el, 0.0)
				foes[i].queue_redraw()
			await process_frame
		await RenderingServer.frame_post_draw
		out.append(_grab(player))
	var strip := Image.create(CROP.x * out.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in out.size():
		strip.blit_rect(out[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	strip.save_png(OS.get_cmdline_user_args()[0])
	quit()


func _grab(player: Node2D) -> Image:
	var img := root.get_texture().get_image()
	var at := Vector2i(player.get_global_transform_with_canvas().origin * Vector2(img.get_size()) / root.get_visible_rect().size)
	var c := (at - Vector2i(CROP.x / 2, 40)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
